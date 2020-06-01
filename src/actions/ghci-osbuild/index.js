const core = require('@actions/core');
const proc = require('child_process');

try {
        const arg_actor = String(core.getInput('actor'));
        const arg_image = String(core.getInput('image'));
        const arg_run = String(core.getInput('run'));
        const arg_token = String(core.getInput('token'));

        arg_cwd = process.cwd();

        if (arg_token.length > 0) {
                console.log('Authenticate to GitHub Packages');
                console.log('--------------------------------------------------------------------------------');
                proc.execFileSync(
                        '/usr/bin/docker',
                        [
                                'login',
                                'docker.pkg.github.com',
                                '--username',
                                arg_actor,
                                '--password',
                                arg_token
                        ],
                        {
                                stdio: 'inherit'
                        }
                );
                console.log('--------------------------------------------------------------------------------');
        }

        console.log('Pull CI Image');
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

        console.log('Execute CI');
        console.log('--------------------------------------------------------------------------------');
        proc.execFileSync(
                '/usr/bin/docker',
                [
                        'run',
                                '--net=host',
                                '--privileged',
                                '--rm',
                                '--volume=' + arg_cwd + ':/ci/workdir',
                                '--volume=/lib/modules/:/lib/modules/',
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

        console.log(`End of CI`);
} catch (error) {
        core.setFailed(error.message);
}
