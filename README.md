# epages-docs

[![Circle CI](https://circleci.com/gh/ePages-de/epages-docs/tree/master.svg?style=svg)](https://circleci.com/gh/ePages-de/epages-docs/tree/master)

## Usage

Tip: You can skip these steps if you prefer to run the site via docker (see section below).

~~~ bash
# install dependencies
$ bundle

# run a local server with auto rebuilding
$ rake

# check for dead links and other bad stuff
$ rake test

# build the page
$ rake build

# update the RAML files from epagesj
$ rake ramlup
~~~

## Bootstrap your machine

Generally speaking you need only to make sure you have installed [Ruby][ruby] and [Bundler][bundler]. For platform specific instructions see the following subsections:

### Mac OS X

You can use this [shell script][bootstrap-macosx] to turn your OS X laptop into an awesome web development machine.

### Linux

You can use this [shell script][bootstrap-linux] to turn your laptop into an awesome web development machine.

### Windows

TODO

## Run a Docker container for development

If you don't like to bootstrap your machine you can run a [Docker][Docker] container for development. It can be pulled from our registry. You need to have [Docker Engine][docker-engine] installed.

~~~ bash
# build locally (instead of pull from our registry)
$ docker build -t epages.com/docs-dev -f Dockerfile.ruby .

# pull container and serve repo as jekyll site
$ docker run --rm --volume=$(pwd):/usr/src/epages-docs -p 127.0.0.1:4000:4000 docker.epages.com/epages/docs-ruby

# run bash in the container and use like local machine (all rake tasks possible)
$ docker run --rm --volume=$(pwd):/usr/src/epages-docs -p 127.0.0.1:4000:4000 -it docker.epages.com/epages/docs-ruby bash

# run via docker machine on a mac
$ export IP=$(docker-machine ip `docker-machine active`)
$ echo "Open in browser: http://${IP}:4000/"
$ docker run --rm --volume=$(pwd):/usr/src/epages-docs -p ${IP}:4000:4000 -it docker.epages.com/epages/docs-ruby
~~~

## License

This project comprises different licenses: The editorial content in the folders

* `apps/`,
* `blog/`,
* `soap/`,
* `themes/` and
* `assets/images/`

is licensed under [CC-BY-4.0][license-cc-by-40]. The logos in the folder `assets/logos/` may not be shared or adapted. The different fonts in the `assets/fonts/` folder are licensed under their own respective licenses. All other content is licensed under [MIT][license-mit].

[epagesdocs]: http://developer.epages.com/
[ruby]: https://www.ruby-lang.org/
[bundler]: http://bundler.io/

[bootstrap-macosx]: https://github.com/thoughtbot/laptop
[bootstrap-linux]: https://github.com/thoughtbot/laptop/blob/3897ad81ee241cbff4501e779c8cde50de79e142/linux

[vagrant]: https://www.vagrantup.com/
[virtualbox]: https://www.virtualbox.org/
[docker-engine]: https://docs.docker.com/engine/installation/

[license-cc-by-40]: http://creativecommons.org/licenses/by/4.0/
[license-mit]: http://opensource.org/licenses/MIT
