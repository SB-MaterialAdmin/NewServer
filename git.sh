#!/bin/bash
echo // Git revision file generator for CI
echo // Written by CrazyHackGUT aka Kruzya
echo //
echo // File generated at $(date -Ru)
echo //
echo // Commit hashes
echo \#define GIT_COMMIT_FULLHASH        \"$(git log --pretty=format:'%H' -n 1)\"
echo \#define GIT_COMMIT_ABBREVIATEDHASH \"$(git log --pretty=format:'%h' -n 1)\"
echo
echo // Tree hashes
echo \#define GIT_TREE_FULLHASH        \"$(git log --pretty=format:'%T' -n 1)\"
echo \#define GIT_TREE_ABBREVIATEDHASH \"$(git log --pretty=format:'%t' -n 1)\"
echo
echo // Previous commit hashes
echo \#define GIT_PARENTCOMMIT_FULLHASH        \"$(git log --pretty=format:'%P' -n 1)\"
echo \#define GIT_PARENTCOMMIT_ABBREVIATEDHASH \"$(git log --pretty=format:'%p' -n 1)\"
echo
echo // Author details
echo \#define GIT_AUTHOR_NAME              \"$(git log --pretty=format:'%aN' -n 1)\"
echo \#define GIT_AUTHOR_MAIL              \"$(git log --pretty=format:'%aE' -n 1)\"
echo \#define GIT_AUTHOR_DATE_FULL_RFC2822 \"$(git log --pretty=format:'%aD' -n 1)\"
echo \#define GIT_AUTHOR_DATE_FULL_ISO8601 \"$(git log --pretty=format:'%aI' -n 1)\"
echo \#define GIT_AUTHOR_DATE_UNIX         \"$(git log --pretty=format:'%at' -n 1)\"
echo
echo // Commiter details
echo \#define GIT_COMMITER_NAME              \"$(git log --pretty=format:'%cN' -n 1)\"
echo \#define GIT_COMMITER_MAIL              \"$(git log --pretty=format:'%cE' -n 1)\"
echo \#define GIT_COMMITER_DATE_FULL_RFC2822 \"$(git log --pretty=format:'%cD' -n 1)\"
echo \#define GIT_COMMITER_DATE_FULL_ISO8601 \"$(git log --pretty=format:'%cI' -n 1)\"
echo \#define GIT_COMMITER_DATE_UNIX         \"$(git log --pretty=format:'%ct' -n 1)\"
echo
echo // Another additional stuff
echo \#define GIT_REF_NAME   \"$(git log --pretty=format:'%S' -n 1)\"
