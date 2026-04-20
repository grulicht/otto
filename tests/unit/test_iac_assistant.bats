#!/usr/bin/env bats
# OTTO - IaC assistant tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    source "${OTTO_DIR}/scripts/core/iac-assistant.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "iac_scaffold_dockerfile creates Dockerfile for python" {
    local outdir="${OTTO_HOME}/docker-test"
    iac_scaffold_dockerfile "python" "none" "$outdir"
    [ -f "${outdir}/Dockerfile" ]
}

@test "iac_scaffold_dockerfile python content has multi-stage build" {
    local outdir="${OTTO_HOME}/docker-py"
    iac_scaffold_dockerfile "python" "none" "$outdir"
    grep -q "FROM python" "${outdir}/Dockerfile"
    grep -q "HEALTHCHECK" "${outdir}/Dockerfile"
}

@test "iac_scaffold_dockerfile creates Dockerfile for node" {
    local outdir="${OTTO_HOME}/docker-node"
    iac_scaffold_dockerfile "node" "none" "$outdir"
    [ -f "${outdir}/Dockerfile" ]
    grep -q "FROM node" "${outdir}/Dockerfile"
}

@test "iac_scaffold_dockerfile Dockerfile has non-root user" {
    local outdir="${OTTO_HOME}/docker-secure"
    iac_scaffold_dockerfile "python" "none" "$outdir"
    grep -q "USER" "${outdir}/Dockerfile"
}

@test "iac_scaffold_terraform creates module files" {
    local outdir="${OTTO_HOME}/tf-test"
    iac_scaffold_terraform "mymodule" "aws" "ec2,s3" "$outdir"
    [ -f "${outdir}/main.tf" ]
    [ -f "${outdir}/variables.tf" ]
    [ -f "${outdir}/outputs.tf" ]
}

@test "iac_scaffold_terraform main.tf contains provider" {
    local outdir="${OTTO_HOME}/tf-provider"
    iac_scaffold_terraform "test" "aws" "" "$outdir"
    grep -q "provider.*aws" "${outdir}/main.tf"
}
