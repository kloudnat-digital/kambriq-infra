# THROWAWAY - proves the environment-convention gate refuses a violation.
#
# This branch exists only to demonstrate the gate. While its CI runs, a live SSM
# parameter (/kambriq/dev/_convention-probe-a29-delete-me) carries
# Environment="staging", a value outside shared/prod/dev. The convention check
# reads the live account tagging API, finds it, and the CI Gate refuses this
# pull request. The branch and the probe are both deleted afterwards.
#
# This file itself is inert - a comment. The violation is the live probe, because
# the check judges what AWS actually holds, not what a plan proposes.
