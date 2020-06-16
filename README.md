# Terraform module Kubeflow

This is a module deploying kubeflow purely in Terraform.

[![maintained by dataroots](https://img.shields.io/badge/maintained%20by-dataroots-%2300b189)](https://dataroots.io)
[![Terraform 0.12](https://img.shields.io/badge/terraform-0.12-%23623CE4)](https://www.terraform.io)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-%23623CE4)](https://registry.terraform.io/modules/datarootsio/kubeflow/module/)
[![tests](https://github.com/datarootsio/terraform-module-kubeflow/workflows/tests/badge.svg?event=pull_request)](https://github.com/datarootsio/terraform-module-kubeflow/actions)
[![Go Report Card](https://goreportcard.com/badge/github.com/datarootsio/terraform-module-kubeflow)](https://goreportcard.com/report/github.com/datarootsio/terraform-module-kubeflow)

## Outputs

No output.

## Contributing

Contributions to this repository are very welcome! Found a bug or do you have a suggestion? Please open an issue. Do you know how to fix it? Pull requests are welcome as well! To get you started faster, a Makefile is provided.

Make sure to install [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html), [Go](https://golang.org/doc/install) (for automated testing) and Make (optional, if you want to use the Makefile) on your computer. Install [tflint](https://github.com/terraform-linters/tflint) to be able to run the linting.

* Setup tools & dependencies: `make tools`
* Format your code: `make fmt`
* Linting: `make lint`
* Run tests: `make test` (or `go test -timeout 2h ./...` without Make)

To run the automated tests, you need to be logged in to a kubernetes cluster. We use [k3s](https://k3s.io/) in the test pipelines.

## License

MIT license. Please see [LICENSE](LICENSE.md) for details.