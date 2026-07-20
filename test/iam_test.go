// Package test contains Terratest-based integration tests for the
// terraform-aws-iam module. These tests provision real IAM resources in an
// AWS account (IAM is a free/global service, so this incurs no cost) and
// tear them down afterwards. They require valid AWS credentials in the
// environment (e.g. AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY or an AWS_PROFILE)
// with permission to create/read/delete IAM roles, instance profiles, and
// policy attachments.
//
// Run with:
//
//	cd test && go mod tidy && go test -v -timeout 30m
//
// For fast, credential-free checks against mocked resources, see the native
// Terraform tests in ../tests/iam.tftest.hcl (`terraform test`) instead.
package test

import (
	"fmt"
	"strings"
	"testing"

	awssdk "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIamRoleComplete(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomStableRegion(t, nil, nil)
	roleName := fmt.Sprintf("terratest-iam-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/complete",
		Vars: map[string]interface{}{
			"region":      awsRegion,
			"name":        roleName,
			"environment": "test",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	roleArn := terraform.Output(t, terraformOptions, "role_arn")
	roleNameOutput := terraform.Output(t, terraformOptions, "role_name")
	instanceProfileName := terraform.Output(t, terraformOptions, "instance_profile_name")
	instanceProfileArn := terraform.Output(t, terraformOptions, "instance_profile_arn")

	require.NotEmpty(t, roleArn)
	require.NotEmpty(t, roleNameOutput)
	assert.Contains(t, roleArn, "role/"+roleNameOutput)
	assert.NotEmpty(t, instanceProfileName)
	assert.NotEmpty(t, instanceProfileArn)

	// Cross-check against the live AWS API rather than trusting Terraform
	// state/outputs alone.
	iamClient := aws.NewIamClient(t, awsRegion)

	getRoleOutput, err := iamClient.GetRole(&iam.GetRoleInput{
		RoleName: awssdk.String(roleNameOutput),
	})
	require.NoError(t, err)
	assert.Equal(t, roleNameOutput, awssdk.StringValue(getRoleOutput.Role.RoleName))
	assert.Equal(t, roleArn, awssdk.StringValue(getRoleOutput.Role.Arn))

	attachedPolicies, err := iamClient.ListAttachedRolePolicies(&iam.ListAttachedRolePoliciesInput{
		RoleName: awssdk.String(roleNameOutput),
	})
	require.NoError(t, err)
	assert.Len(t, attachedPolicies.AttachedPolicies, 1, "expected exactly one managed policy attachment")

	getInstanceProfileOutput, err := iamClient.GetInstanceProfile(&iam.GetInstanceProfileInput{
		InstanceProfileName: awssdk.String(instanceProfileName),
	})
	require.NoError(t, err)
	assert.Equal(t, instanceProfileArn, awssdk.StringValue(getInstanceProfileOutput.InstanceProfile.Arn))
	require.Len(t, getInstanceProfileOutput.InstanceProfile.Roles, 1)
	assert.Equal(t, roleNameOutput, awssdk.StringValue(getInstanceProfileOutput.InstanceProfile.Roles[0].RoleName))
}
