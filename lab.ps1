<#
  Windows runner — the equivalent of `make <target>` for students without make.
#>
param(
    [Parameter(Position = 0)] [string] $Target = "help",
    [Parameter(ValueFromRemainingArguments = $true)] [string[]] $Rest
)

$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
Set-Location $PSScriptRoot

$VenvPy = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$Port   = if ($env:LAB_SERVER_PORT) { $env:LAB_SERVER_PORT } else { '8080' }
$SysPy  = 'python'

function Need-Venv {
    if (-not (Test-Path $VenvPy)) {
        Write-Host "ERROR: no virtualenv found at .venv\" -ForegroundColor Red
        Write-Host "Run this first:  .\lab.ps1 setup"
        exit 1
    }
}

function Py { Need-Venv; & $VenvPy @args; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }

function Locust {
    Need-Venv
    & $VenvPy -m locust @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

switch ($Target) {
    'help' {
        Write-Host ""
        Write-Host "Day 20 lab — Windows runner" -ForegroundColor Cyan
        Write-Host "Usage:  .\lab.ps1 <target>"
        Write-Host ""
        Write-Host "Setup (00)"
        Write-Host "  probe          Probe hardware -> hardware.json"
        Write-Host "  setup          Install deps + llama.cpp runtime + Gemma 4 E2B"
        Write-Host "  runtime        Re-fetch just the llama.cpp binaries"
        Write-Host ""
        Write-Host "Measure (01)"
        Write-Host "  bench          TTFT / TPOT / percentiles, both quantizations"
        Write-Host "  tune           Thread sweep -> your before/after speedup"
        Write-Host ""
        Write-Host "Serve (02)"
        Write-Host "  serve          Start llama-server on :8080 (leave running)"
        Write-Host "  serve-embed    Embedding server on :8081 (bonus C9)"
        Write-Host "  smoke          Prove the API + non-zero /metrics"
        Write-Host "  load-10        Load test, 10 users, 60s"
        Write-Host "  load-50        Load test, 50 users, 60s"
        Write-Host "  metrics        Sample /metrics 60s (run WHILE load-50 runs)"
        Write-Host "  load-report    Saturation reading from both load runs"
        Write-Host ""
        Write-Host "Integrate (03)"
        Write-Host "  pipeline       RAG pipeline -> llama-server"
        Write-Host ""
        Write-Host "Check and Submit"
        Write-Host "  verify         Checklist before submitting"
        Write-Host "  clean          Wipe benchmarks\ (keep venv + models + runtime)"
        Write-Host "  clean-all      Wipe everything including venv, runtime, models"
        Write-Host ""
        Write-Host "Bonus"
        Write-Host "  sweep-quant · sweep-ctx · sweep-batch · sweep-gpu · build-llama"
        Write-Host "  compare-builds · embed-demo · semantic-cache"
        Write-Host ""
    }

    'probe'   { & $SysPy labs\00-setup\detect-hardware.py }
    'setup'   { & $SysPy labs\00-setup\setup.py @Rest }
    'runtime' { & $SysPy labs\00-setup\setup.py --runtime-only }

    'bench'   { Py labs\01-measure\benchmark.py }
    'tune'    { Py labs\01-measure\tune.py @Rest }

    'serve'       { Py labs\02-serve\serve.py @Rest }
    'serve-embed' { Py labs\02-serve\serve.py --embedding @Rest }
    'smoke'       { Py labs\02-serve\smoke-test.py }
    'load-10'     { Locust -f labs\02-serve\load-test.py --headless -u 10 -r 5 -t 1m --host http://localhost:$Port --csv benchmarks\locust-10 --csv-full-history }
    'load-50'     { Locust -f labs\02-serve\load-test.py --headless -u 50 -r 25 -t 1m --host http://localhost:$Port --csv benchmarks\locust-50 --csv-full-history }
    'metrics'     { Py labs\02-serve\record-metrics.py --duration 60 --label u50 }
    'load-report' { Py labs\02-serve\load-report.py }

    'pipeline' { Py labs\03-integrate\pipeline.py @Rest }

    # verify must work with system Python too: the grader has no .venv.
    'verify' { & $SysPy scripts\verify.py; exit $LASTEXITCODE }

    'sweep-quant' { Py bonus\sweeps\quant-sweep.py @Rest }
    'sweep-ctx'   { Py bonus\sweeps\ctx-len-sweep.py @Rest }
    'sweep-batch' { Py bonus\sweeps\batch-size-sweep.py @Rest }
    'sweep-gpu'   { Py bonus\sweeps\gpu-offload-sweep.py @Rest }
    'compare-builds' { Py bonus\compare-builds.py @Rest }
    'embed-demo'             { Py bonus\serving-regimes\embedding-serving.py @Rest }
    'embed-demo-offline'     { Py bonus\serving-regimes\embedding-serving.py --offline }
    'semantic-cache'         { Py bonus\serving-regimes\semantic-cache-demo.py @Rest }
    'semantic-cache-offline' { Py bonus\serving-regimes\semantic-cache-demo.py --offline --sweep }

    'build-llama' {
        foreach ($t in 'cmake', 'git') {
            if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
                Write-Host "ERROR: $t not found. Install Visual Studio Build Tools + cmake + git." -ForegroundColor Red
                exit 1
            }
        }
        $build = & $VenvPy -c "import sys;sys.path.insert(0,'lib');import labkit;print(labkit.LLAMA_CPP_BUILD)"
        if (-not (Test-Path 'bonus\llama.cpp')) {
            git clone --depth 1 --branch $build https://github.com/ggml-org/llama.cpp bonus\llama.cpp
        }
        $flags = if ($env:LLAMA_CMAKE_FLAGS) { $env:LLAMA_CMAKE_FLAGS -split ' ' } else { @() }
        cmake -B bonus\llama.cpp\build -S bonus\llama.cpp @flags -DGGML_NATIVE=ON -DCMAKE_BUILD_TYPE=Release
        cmake --build bonus\llama.cpp\build -j --config Release
        Write-Host ""
        Write-Host "Built. Now compare it against the prebuilt binary:  .\lab.ps1 compare-builds"
    }

    'clean' {
        Get-ChildItem -Path benchmarks -Include "01-*.md","01-*.json","02-*.md","02-*.json","02-*.csv","03-*.md","03-*.json","locust-*.csv","bonus-*.md","bonus-*.json" -ErrorAction SilentlyContinue | Remove-Item -Force
        Write-Host "Cleaned generated reports. Kept hardware.json, models\, runtime\, submission\."
    }

    'clean-all' {
        Get-ChildItem -Path benchmarks -Include "01-*.md","01-*.json","02-*.md","02-*.json","02-*.csv","03-*.md","03-*.json","locust-*.csv","bonus-*.md","bonus-*.json" -ErrorAction SilentlyContinue | Remove-Item -Force
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .venv, runtime, models, bonus\llama.cpp, hardware.json
        Write-Host "Removed venv, runtime, models and hardware.json. Re-run: .\lab.ps1 setup"
    }

    default {
        Write-Host "Unknown target: $Target" -ForegroundColor Red
        Write-Host "Run  .\lab.ps1  with no arguments to list targets."
        exit 1
    }
}
