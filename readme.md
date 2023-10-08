# GitHub Self-Hosted Runner Docker

Docker image that can be used for self-hosting GitHub Actions Runner.

## Details

- Fully isolated environment for job execution. There's no need to any post-run cleanups.
- Based on Ubuntu Docker image with the latest Docker version installed
- Provides some applications pre-installed. See the list of packages installed in addition to what the base image provides in the [Dockerfile](./Dockerfile).

## Architecture

The deployment model that I had in mind that this Docker image plays well within is something like below:

1. Docker containers are created, or replaced with existing ones, and managed by Docker Compose
2. A job that is assigned to a runner by GitHub will be executed by a runner, e.g., `Runner #3`
3. Once the runner has finished a job that was assigned to it, either with success, or failure result, it will be both unregistered from GitHub, and its container will be removed
4. As Docker Compose is configured to keep the specified number of container instances up and running (using `restart: always` option), it will recreate the container that was just removed
5. The newly (re)created container will register itself to GitHub, and it'll be listening for new jobs

## Usage

<!-- TODO -->

## Next Steps

- Try [sysbox](https://github.com/nestybox/sysbox) under a reasonably complex workflow job execution hoping to get rid of privileged container run.
- Simplify scale up & down. Maybe a simple helper script over Docker Compose command line, or something that generates a Compose-compliant spec file, and pipes it into Docker Compose would suffice.
- Currently, Docker images are built for `linux/amd64` OS architectures. This can be extended to support other OSs/architectures if there are enough demand, and help for testing, or maintaining the image.

## Issues

- As I'm not much experienced in Bash scripting, there are some improvements that must be made to the scripts used by the image, specially [`start.sh`](./start.sh), and [`entrypoint.sh`](./entrypoint.sh), for example to handle graceful Docker Daemon shutdown, and make sure that processes launched by these scripts are killed/stopped.

## Credits

The following are some of the resources that I used to achieve this

- <https://testdriven.io/blog/github-actions-docker/>
- <https://github.com/docker-library/docker/issues/306>
