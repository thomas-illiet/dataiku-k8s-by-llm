SHELL := /usr/bin/env bash

.PHONY: help test test-static test-help test-render test-build test-cluster test-e2e

help:
	@printf '%s\n' 'Dataiku Kubernetes test harness'
	@printf '%s\n' ''
	@printf '%s\n' 'Targets:'
	@printf '%s\n' '  test-static   Local checks without Docker or cluster'
	@printf '%s\n' '  test-help     Validate script --help and missing-env failures'
	@printf '%s\n' '  test-render   Render Helm waves and parse rendered YAML'
	@printf '%s\n' '  test-build    Build and inspect runtime image; requires DSS kit and Docker'
	@printf '%s\n' '  test-cluster  Validate Argo CD/Helm objects against a test cluster'
	@printf '%s\n' '  test-e2e      Run cluster smoke tests after deployment'
	@printf '%s\n' '  test          Run test-static and test-help'

test: test-static test-help

test-static:
	@./scripts/test-static.sh

test-help:
	@./scripts/test-help.sh

test-render:
	@./scripts/test-render.sh

test-build:
	@./scripts/test-build.sh

test-cluster:
	@./scripts/test-cluster.sh

test-e2e:
	@./scripts/test-e2e.sh

