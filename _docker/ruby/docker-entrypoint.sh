#!/bin/bash

# If any script fails then exit 1.
set -e

# If the first argument is rake 
# then own all mounted volumes with epages user
# and run given rake task as epages user.
if [[ "${1}" = 'rake' ]]; then
	gosu ${EPAGES_USER} bundle exec jekyll build -t
    chown -R ${EPAGES_USER}:${EPAGES_USER} ${RUBY_HOME} ${EPAGES_DOCS}
    set bundle exec jekyll serve --host 0.0.0.0 --watch
fi

# If the first argument is test, build or index 
# then own all mounted volumes with epages user
# and run the parameter as complete rake task as epages user.
if [[ "${1}" =~ ^.*(test)|(build)|(index).*$ ]]; then
    chown -R ${EPAGES_USER}:${EPAGES_USER} ${EPAGES_DOCS}
    set -- gosu ${EPAGES_USER} rake "${@}"
fi

# If the argument is not related to ruby (e.g. `bash`) then run it as root.
exec "${@}"
