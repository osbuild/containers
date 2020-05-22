const core = require('@actions/core');
const proc = require('child_process');

try {
        const arg_host = String(core.getInput('host'));
        const arg_port = String(core.getInput('port'));
        const arg_timeout = String(core.getInput('timeout'));
        const arg_hostport = arg_host + ':' + arg_port;

        let r = 1;
        let now = Date.now();
        let endtime = now + arg_timeout * 1000;

        console.log('--------------------------------------------------------------------------------');
        console.log('Wait for: ' + arg_hostport);
        while (r != 0) {
                if (now > endtime) {
                        console.log('Time ran out waiting for: ' + arg_hostport);
                        throw new Error('Network Timeout');
                } else {
                        now = Date.now();
                }

                try {
                        proc.execFileSync(
                                '/bin/nc',
                                [
                                        '-z',
                                        arg_host,
                                        arg_port,
                                ],
                                {
                                        stdio: 'inherit'
                                }
                        );
                        r = 0;
                } catch (e) {
                        r = 1;
                        if (e.status !== 1) {
                                console.log('Unexpected Failure: ', e)
                        }
                        proc.execSync("sleep 0.2");
                }
        }
        console.log('Now available: ' + arg_hostport);
        console.log('--------------------------------------------------------------------------------');
} catch (e) {
        core.setFailed(e.message);
}
