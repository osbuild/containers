#!/usr/bin/python3

"""Ghrunt - Entrypoint

Entrypoint of the GitHub-Actions-Runner container. See the Dockerfile for
the general setup. This entrypoint registers the runner and spawns it.
"""


import argparse
import contextlib
import json
import os
import subprocess
import sys
import urllib.request


class Ghrunt(contextlib.AbstractContextManager):
    """Application Runtime Class"""

    def __init__(self, argv):
        self.args = None
        self._argv = argv
        self._parser = None

    def _parse_args(self):
        self._parser = argparse.ArgumentParser(
            add_help=True,
            allow_abbrev=False,
            argument_default=None,
            description="GitHub-Actions-Runner Terminal",
            prog="ghrunt",
        )
        self._parser.add_argument(
            "--labels",
            help="Additional labels for the runner (comma separated)",
            metavar="LIST",
            type=str,
        )
        self._parser.add_argument(
            "--name",
            help="Unique-name of this runner",
            metavar="STRING",
            type=str,
        )
        self._parser.add_argument(
            "--pat",
            help="Personal Access Token",
            metavar="TOKEN",
            type=str,
        )
        self._parser.add_argument(
            "--registry",
            help="Organization or repository to register on",
            metavar="ORG/REPO",
            type=str,
        )

        return self._parser.parse_args(self._argv[1:])

    def _parse_env(self):
        self.args.labels = self.args.labels or os.getenv("GHRUNT_ARG_LABELS", None)
        self.args.name = self.args.name or os.getenv("GHRUNT_ARG_NAME", None)
        self.args.pat = self.args.pat or os.getenv("GHRUNT_ARG_PAT", None)
        self.args.registry = self.args.registry or os.getenv("GHRUNT_ARG_REGISTRY", None)

    def _verify_args(self):
        assert self.args.labels
        assert self.args.name
        assert self.args.pat
        assert self.args.registry

    def _prepare_user(self):
        # OpenShift runs containers with a random UID. Prepare a fresh
        # home-directory, add a `passwd` entry and set the environment up.
        os.makedirs("/ghrunt/oci", exist_ok=False)
        os.chdir("/ghrunt/oci")
        os.environ["HOME"] = "/ghrunt/oci"

        uid = os.getuid()
        with open("/etc/passwd", "a") as filp:
            filp.write(f"ghrunt-oci:x:{uid}:0::/ghrunt/oci:/bin/bash\n")

    def __enter__(self):
        self.args = self._parse_args()
        self._parse_env()
        self._verify_args()
        self._prepare_user()
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        pass

    def _acquire_token(self):
        """Acquire Git Hub Runner Token

        Git Hub provides an API to acquire a registration token for the runner
        application. They use Azure Pipelines internally, so the standard
        Git Hub tokens are not sufficient. Instead, we use a normal Git Hub
        PAT (Personal Access Token) to access the Git Hub API and acquire an
        Azure token for the runner.

        This token is only valid for 24h (or as long as a registered runner
        uses it), so there is no point in caching it. We re-acquire it on every
        run.

        You need a PAT with full `repo` access for this to work.
        """

        url = "https://api.github.com/"
        if "/" in self.args.registry:
            url += f"repos/{self.args.registry}"
        else:
            url += f"orgs/{self.args.registry}"
        url += "/actions/runners/registration-token"

        request = urllib.request.Request(
            url=url,
            data="".encode(),
            headers={
                "Accept": "application/vnd.github.v3+json",
                "Authorization": f"token {self.args.pat}",
            },
        )

        with urllib.request.urlopen(request) as filp:
            data = json.load(filp)

        return data.get("token")

    def _extract_runner(self):
        """Extract Runner

        Extract the runner application into a new directory, so everything
        is prepared to be run by our context.
        """

        subprocess.run(
            [
                "tar",
                "-xz",
                "-C", "/ghrunt/oci",
                "-f", "/ghrunt/runner/actions-runner-linux.tar.gz",
            ],
            check=True,
        )

    def _configure_runner(self, token):
        """Configure Runner Application

        Use the `config.sh` script shipped with the Git Hub Runner application
        to configure the runner. This will write configuration files with all
        this information included.
        """

        subprocess.run(
            [
                "./config.sh",
                "--labels", self.args.labels,
                "--name", self.args.name,
                "--replace",
                "--token", token,
                "--unattended",
                "--url", f"https://github.com/{self.args.registry}",
                "--work", "/ghrunt/workdir",
            ],
            check=True,
        )

    def _spawn_runner(self):
        """Spawn Runner

        This synchronously executes the Git Hub Runner application. We use the
        `run.sh` wrapper script shipped with the Git Hub Runner executable.
        """

        while True:
            res = subprocess.run(
                [
                    "./run.sh"
                ],
                check=False,
            )
            print(f"Runner exited with exitcode '{res.returncode}'.")
            if res.returncode not in [0, 2, 3, 4]:
                print("Exit.")
                break
            else:
                print("Retry.")

    def _remove_runner(self, token):
        """Remove Runner

        Remove the Git Hub registration of the local runner. This will make
        sure no registration is left on Git Hub when the runner exits. We
        always use ephemeral runners, so we want them to register/unregister
        as they come and go. We do not use stateful runners.

        This will fail if there is no matching registration, but this should
        not matter.
        """

        subprocess.run(
            [
                "./config.sh",
                "remove",
                "--token", token,
            ],
            check=True,
        )

    def run(self):
        """Run Application"""

        print("Acquire token from GitHub...")
        token = self._acquire_token()
        print("Token:", token)

        print("Extract runner...")
        self._extract_runner()
        print("Extracted.")

        try:
            print("Configure runner...")
            self._configure_runner(token)
            print("Configured.")

            print("Execute runner...", flush=True)
            self._spawn_runner()
            print("Finished.")
        finally:
            print("Remove runner...")
            self._remove_runner(token)
            print("Removed.")

        print("Done.")


if __name__ == "__main__":
    with Ghrunt(sys.argv) as global_main:
        sys.exit(global_main.run())
