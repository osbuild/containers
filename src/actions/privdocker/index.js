const core = require('@actions/core');
const proc = require('child_process');

try {
        const arg_image = String(core.getInput('image'));
        const arg_run = String(core.getInput('run'));

        arg_cwd = process.cwd();

        console.log('Pull Image');
        console.log('--------------------------------------------------------------------------------');
        proc.execFileSync(
                '/usr/bin/docker',
                [
                        'pull',
                        '--quiet',
                        arg_image
                ],
                {
                        stdio: 'inherit'
                }
        );
        console.log('--------------------------------------------------------------------------------');

        console.log('Execute Image');
        console.log('--------------------------------------------------------------------------------');
        proc.execFileSync(
                '/usr/bin/docker',
                [
                        'run',
                                '--net=host',
                                '--privileged',
                                '--rm',
                                '--volume=/:/osb/host',
                                '--volume=' + arg_cwd + ':/osb/workdir',
                                '--volume=/lib/modules/:/lib/modules/',
                                '--volume=/var/run/docker.sock:/var/run/docker.sock',
                                arg_image,
                                '/bin/bash',
                                        '-o', 'errexit',
                                        '-c', arg_run
                ],
                {
                        stdio: 'inherit'
                }
        );
        console.log('--------------------------------------------------------------------------------');

        console.log(`End of Execution`);
} catch (error) {
        core.setFailed(error.message);
}
