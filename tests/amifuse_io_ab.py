"""A/B device-request counts between two handler binaries. Counts requests, not Amiga wall-clock time.

Status: handler-in-the-loop tier, by hand. Without FAT95_BASELINE_DRIVER it measures the current driver alone.
Run: python3 tests/amifuse_io_ab.py"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from amifuse_bridge import RawFatBridge
from amifuse_images import create_image, file_sha256, verify_image
from amifuse_suite import DEFAULT_DRIVERS, payload
from toolchain import RUNS

# Controlled batching: hold only timer requests pending during the workload.
# No handler globals/code changes; release before shutdown. Not a time model.
from amitools.vamos.lib.ExecLibrary import ExecLibrary
from amitools.vamos.lib.TimerDevice import TimerDevice
_timer_requests=set()
_hold_timer=False
_original_timer=TimerDevice.BeginIO
_original_check=ExecLibrary.CheckIO

def timer_begin(self,ctx,io_request):
    _timer_requests.add(io_request)
    return _original_timer(self,ctx,io_request)

def check_io(self,ctx,io_request):
    if _hold_timer and io_request in _timer_requests:
        return 0
    return _original_check(self,ctx,io_request)

TimerDevice.BeginIO=timer_begin
ExecLibrary.CheckIO=check_io

class MeasuredBridge(RawFatBridge):
    def reset_counts(self):
        self.metrics=dict(read=0,write=0,update=0,read_bytes=0,write_bytes=0)
    def _observe_io(self, request):
        super()._observe_io(request)
        kind={2:'read',3:'write',4:'update'}.get(request.command.val)
        if kind:
            self.metrics[kind]+=1
            if kind!='update':self.metrics[kind+'_bytes']+=request.length.val


def worker(profile, scenario, driver, folder, timer_mode):
    global _hold_timer
    image=folder/'disk.img';create_image(image,profile)
    data=payload(65536)
    seed=folder/'seed.bin';seed.write_bytes(data)
    subprocess.run(['mcopy','-i',str(image),str(seed),'::/SEED.BIN'],check=True,capture_output=True)
    bridge=MeasuredBridge(image,driver)
    bridge.reset_counts()
    _hold_timer=timer_mode=='held'
    expected={'SEED.BIN':data}
    try:
        if scenario=='read-only':
            for _ in range(32):assert bridge.read_file('/SEED.BIN',65536,0)==data
        elif scenario=='large-write':
            block=payload(256*1024)
            bridge.put('/LARGE.BIN',block);expected['LARGE.BIN']=block
        else:
            for n in range(32):
                name=f'S{n:02}.BIN';block=payload(512,n)
                bridge.put('/'+name,block);expected[name]=block
                if scenario=='flush-each':bridge.flush_volume()
        workload=dict(bridge.metrics)
        bridge.reset_counts()
        bridge.flush_volume()
        _hold_timer=False
        bridge.shutdown_handler()
        shutdown=dict(bridge.metrics)
    finally:bridge.close()
    verify_image(image,expected)
    return dict(timer_mode=timer_mode,profile=profile,scenario=scenario,driver_sha256=file_sha256(driver),
                workload=workload,shutdown=shutdown,
                total={k:workload[k]+shutdown[k] for k in workload})

if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--worker':
        profile,scenario,driver,folder,timer_mode=sys.argv[2:]
        folder=Path(folder)
        (folder/'result.json').write_text(json.dumps(worker(profile,scenario,Path(driver),folder,timer_mode),indent=2)+'\n')
    else:
        root=RUNS;root.mkdir(parents=True,exist_ok=True)
        out=Path(tempfile.mkdtemp(prefix='io-ab-',dir=root)).resolve()
        results=[]
        for timer_mode in ['held','eager']:
          for profile in ['fat12_720','fat16_32m','fat32_128m']:
            for scenario in ['read-only','small-batch','flush-each','large-write']:
                for version,driver in DEFAULT_DRIVERS.items():
                    folder=out/f'{timer_mode}-{profile}-{scenario}-{version}';folder.mkdir()
                    with (folder/'run.log').open('w') as log:
                        subprocess.run([sys.executable,__file__,'--worker',profile,scenario,
                                        str(driver),str(folder),timer_mode],stdout=log,stderr=subprocess.STDOUT,
                                       timeout=60,check=True)
                    result=json.loads((folder/'result.json').read_text());result['version']=version
                    results.append(result)
                    print(timer_mode,profile,scenario,version,result['total'],flush=True)
        (out/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
        print(out)
