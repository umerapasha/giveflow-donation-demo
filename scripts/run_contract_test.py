"""Run Dart HTTP adapter tests against a real loopback FastAPI server."""
import argparse
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--flutter-bin',default='flutter')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as tmp:
    env=dict(os.environ,GIVEFLOW_DB=str(Path(tmp)/'contract.sqlite3'),CI='true')
    with open(Path(tmp)/'server.log','w') as log:
        server=subprocess.Popen([sys.executable,'-m','uvicorn','backend.app:app','--host','127.0.0.1','--port','8021'],cwd=root,env=env,stdout=log,stderr=log)
        try:
            for attempt in range(50):
                if server.poll() is not None: raise RuntimeError('Test server stopped before it was ready.')
                try:
                    with urllib.request.urlopen('http://127.0.0.1:8021/health',timeout=.3) as response:
                        if response.status==200:break
                except OSError:time.sleep(.1)
            else:raise RuntimeError('Test server did not become ready.')
            result=subprocess.run([args.flutter_bin,'test','test/api_contract_test.dart','--dart-define=RUN_LOCAL_API=true','--reporter=expanded'],cwd=root,env=env)
        finally:
            server.terminate()
            try:server.wait(timeout=5)
            except subprocess.TimeoutExpired:server.kill();server.wait()
    sys.exit(result.returncode)
