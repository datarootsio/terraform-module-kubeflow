package test

import (
	"strings"
	"testing"
	"time"

	//"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func getDefaultTerraformOptions(t *testing.T) (string, *terraform.Options, error) {

	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "..", ".")

	random_id := strings.ToLower(random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir:       tempTestFolder,
		Vars:               map[string]interface{}{},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Minute,
		NoColor:            false,
		Logger:             logger.TestingT,
	}

	terraformOptions.Vars["install_istio"] = false

	return random_id, terraformOptions, nil
}

func TestApplyAndDestroyWithDefaultValues(t *testing.T) {
	t.Parallel()

	_, options, err := getDefaultTerraformOptions(t)
	assert.NoError(t, err)

	options.Vars["cert_manager_namespace"] = "cert-manager"
	options.Vars["istio_operator_namespace"] = "istio-operator"
	options.Vars["istio_namespace"] = "istio-system"
	options.Vars["ingress_gateway_ip"] = "10.20.30.40"
	options.Vars["use_cert_manager"] = true
	options.Vars["domain_name"] = "foo.local"
	options.Vars["letsencrypt_email"] = "foo@bar.local"
	options.Vars["ingress_gateway_annotations"] = map[string]interface{}{"foo": "bar"}

	defer terraform.Destroy(t, options)
	_, err = terraform.InitAndApplyE(t, options)
	assert.NoError(t, err)
}
