#!/bin/bash
set -e
set -x

REPO_MAIN=$1
REPO_CLIENT=$2
REPO_ACTION=$3

# Check that the repos exist.
REPOS=(
    ${REPO_MAIN}
    ${REPO_CLIENT}
    ${REPO_ACTION}
)

for REPO in "${REPOS[@]}"
do
    if [[ ! -d "${REPO}" ]]; then
        >&2 echo "ERROR: ${REPO} does not exist."
        exit 1
    fi
done

# Setup and activate virtualenv.
cd ${REPO_MAIN}
if [[ -d "${REPO_MAIN}/.venv" ]]; then
    rm -rf ${REPO_MAIN}/.venv
fi
virtualenv --no-site-packages .venv
. ${REPO_MAIN}/.venv/bin/activate

# Temporary hack around the kombu and amqp dependency problem
pip install "kombu>=3.0.0,<4.0.0"
pip install "amqp>=1.4.0,<2.0.0"

# Setup mistral.
cd ${REPO_MAIN}

echo "${REPO_MAIN}"
echo "===== initial contents of requirements.txt ====="
cat requirements.txt

# NB! Sync 'requirements.txt' replacements with recent injects in 'st2-packages'
# Latest: https://github.com/StackStorm/st2-packages/blob/9535deee32bc121a601c9bb885c49cec22cd6022/packages/st2mistral/Makefile#L74-L77
grep -q 'gunicorn' requirements.txt || echo "gunicorn" >> requirements.txt
grep -q 'oslo.cache' requirements.txt || echo "oslo.cache<1.32.0" >> requirements.txt
grep -q 'openstacksdk' requirements.txt || echo "openstacksdk<0.21.0" >> requirements.txt
grep -q 'psycopg2' requirements.txt || echo "psycopg2>=2.6.2,<2.7.0" >> requirements.txt
grep -q 'pika' requirements.txt || echo "pika<0.11,>=0.9" >> requirements.txt
grep -q 'python-memcached' requirements.txt || echo "python-memcached" >> requirements.txt
sed -i "s/^oslo.messaging.*/oslo.messaging==5.24.2/g" requirements.txt
sed -i "s/^Babel.*/Babel>=2.3.4,!=2.4.0 # BSD/g" requirements.txt
sed -i "s/^python-senlinclient.*/python-senlinclient<1.10.0 # Apache-2.0/g" requirements.txt

echo "===== Final contents of requirements.txt ====="
cat requirements.txt

pip install -q -r requirements.txt

# Temporary hack to get around oslo.utils bug.
pip install -q netifaces

python setup.py develop

# Setup plugins for custom actions.
cd ${REPO_ACTION}
python setup.py develop

# Setup mistral client.
cd ${REPO_CLIENT}
pip uninstall -y python-mistralclient
pip install -q -r requirements.txt
python setup.py develop

# Deactivate virtualenv.
deactivate
