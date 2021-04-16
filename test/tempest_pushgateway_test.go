package test

import (
	"testing"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

// An example of how to test the simple Terraform module in examples/terraform-basic-example using Terratest.
func TestTerraformBasicExample(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		NoColor:      true,
	})

	defer test_structure.RunTestStage(t, "clean", func() {
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "test", func() {
		kubectlOptions := k8s.NewKubectlOptions("kind-kind", "", "monitoring")

		filters := metav1.ListOptions{
			LabelSelector: "app=tempest-pushgateway",
		}

		k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 1, 8, 10*time.Second)
	})
}
