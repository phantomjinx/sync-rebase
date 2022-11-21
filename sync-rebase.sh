#!/bin/bash

set +e

display_usage() {
    cat <<EOT
Synchronize rebase a (downstream) GIT repository with changes performed in another (upstream) GIT repository.

Usage: sync-rebase.sh <downstream_org/repo/branch> --upstream <upstream_org/repo/branch> [options]

-i, --interactive             Enable rebase interactive mode (useful to run from a local machine)
-u, --upstream                Upstream org/repository/branch from where to sync
-h, --help                    This help message

EOT
}

# Directory where to temporarily store local repositories and other files
WORKSPACE="/tmp/"

UPSTREAM_ORG=""
UPSTREAM_REPO=""
UPSTREAM_BRANCH=""
UPSTREAM_REMOTE="upstream"
DOWNSTREAM_ORG=""
DOWNSTREAM_REPO=""
DOWNSTREAM_BRANCH=""
INTERACTIVE=""

main() {
  parse_args $@

  pushd ${WORKSPACE} &>/dev/null

  if [ ! -d .git ]; then
    echo "ERROR: Not a GIT repo or not in the parent directory of the path ${WORKSPACE}. Make sure to run a checkout actions before running this action."
    exit 1
  fi;

  echo "Adding ${UPSTREAM_ORG}/${UPSTREAM_REPO} remote as ${UPSTREAM_REMOTE} ... "
  git remote add -f ${UPSTREAM_REMOTE} https://github.com/${UPSTREAM_ORG}/${UPSTREAM_REPO}.git

  # Check if the branches exist
  echo "Checking if branch ${DOWNSTREAM_BRANCH} exists ... "
  downstream_branch_exists=$(git branch -a | grep remotes/origin/${DOWNSTREAM_BRANCH})
  if [ "${downstream_branch_exists}" == "" ]
  then
    echo "ERROR: the ${DOWNSTREAM_BRANCH} branch does not exist on ${DOWNSTREAM_ORG}/${DOWNSTREAM_REPO} repository."
    echo "Make sure the downstream branch exists before retrying the synchronization process."
    exit 1
  fi

  echo "Checking upstream branch ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} exists ... "
  upstream_branch_exists=$(git branch -a | grep remotes/${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH})
  if [ "${upstream_branch_exists}" == "" ]; then
    echo "ERROR: the ${UPSTREAM_BRANCH} branch does not exist on ${UPSTREAM_ORG}/${UPSTREAM_REPO} repository."
    echo "Make sure the upstream branch exists before retrying the synchronization process."
    exit 1
  fi

  echo "Checking out downstream branch ... "
  git checkout -f -b downstream origin/${DOWNSTREAM_BRANCH} &>/dev/null

  echo "Fetching from upstream ... "
  git fetch ${UPSTREAM_REMOTE} ${UPSTREAM_BRANCH} || true

  # if there is a previous rebase attempt, abort it
  echo "Checking whether not already rebasing ... "
  is_rebasing && git rebase --abort

  # try rebase see how far we get
  echo "Trying rebase on ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} ... "
  git rebase ${INTERACTIVE} ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} &>/dev/null

  popd
}

function is_rebasing {
  if [[ "$(git status | grep -c "rebasing")" == "0" ]]; then
      return 1
  else
      return 0
  fi
}

parse_args(){
  if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]
  then
    display_usage
    exit 0
  fi
  re="([^\/]+)\/([^\/]+)\/([^\/]+)"
  [[ "${1}" =~ ${re} ]]
  DOWNSTREAM_ORG=${BASH_REMATCH[1]}
  DOWNSTREAM_REPO=${BASH_REMATCH[2]}
  DOWNSTREAM_BRANCH=${BASH_REMATCH[3]}
  if [ "${DOWNSTREAM_ORG}" == "" ] || [ "${DOWNSTREAM_REPO}" == "" ] || [ "${DOWNSTREAM_BRANCH}" == "" ]
  then
    echo "❗ you must provide a downstream configuration as <org/repo/branch>"
    exit 1
  fi
  shift
  # Parse command line options
  while [ $# -gt 0 ]
  do
      arg="${1}"

      case ${arg} in
        -h|--help)
          display_usage
          exit 0
          ;;
        -f|--force)
          FORCE="true"
          ;;
        -i|--interactive)
          INTERACTIVE="-i"
          ;;
        -u|--upstream)
          shift
          [[ "${1}" =~ $re ]]
          UPSTREAM_ORG=${BASH_REMATCH[1]}
          UPSTREAM_REPO=${BASH_REMATCH[2]}
          UPSTREAM_BRANCH=${BASH_REMATCH[3]}

          if [ "${UPSTREAM_ORG}" == "" ] || [ "${UPSTREAM_REPO}" == "" ] || [ "${UPSTREAM_BRANCH}" == "" ]
          then
            echo "❗ you must provide an upstream repo as -u <org/repo/branch>"
            exit 1
          fi
          ;;
        -p|--path)
          shift
          WORKSPACE="${1}"
          if [ ! -d "${WORKSPACE}" ]; then
            echo "! the provided path for the checked out repository does not exist"
            exit 1
          fi
          ;;
        *)
          echo "❗ unknown argument: ${1}"
          display_usage
          exit 1
          ;;
      esac
      shift
  done
}

main $*
