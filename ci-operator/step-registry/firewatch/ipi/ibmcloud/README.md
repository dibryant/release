# firewatch-ipi-ibmcloud workflow<!-- omit from toc -->

## Table of Contents<!-- omit from toc -->

- [Purpose](#purpose)
- [Process](#process)

## Purpose

The `firewatch-ipi-ibmcloud` workflow is a copy of the `ipi-ibmcloud` workflow with an additional `post` step used to report Jira issues for failed OpenShift CI jobs. Please see the [CSPI-QE/firewatch](https://github.com/CSPI-QE/firewatch) repository for more documentation on the firewatch tool.

## Process

The additional step(s) used in this workflow are as follows:

- **post steps**
  - [`firewatch-report-issues`](../../report-issues/firewatch-report-issues-ref.yaml)

Please see the [`ipi-ibmcloud`](https://steps.ci.openshift.org/workflow/ipi-ibmcloud) documentation for more information regarding the steps that are not either of the steps explained above as they are not maintained by the CSPI QE team.