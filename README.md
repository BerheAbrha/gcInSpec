
# gcInSpec module

[![Build Status](https://dev.azure.com/guestconfiguration/gcinspec/_apis/build/status/microsoft.gcInSpec?branchName=master)](https://dev.azure.com/guestconfiguration/gcinspec/_build/latest?definitionId=27&branchName=master)

This project offers a community supported module for
[Azure Policy Guest Configuration](https://aka.ms/gcpol)
to audit virtual machines in Azure using custom
[InSpec](https://inspec.io)
profiles.

Since custom InSpec content is already functional for Linux,
this module will focus on audit of nodes running Windows.
In the future, a single module should be compatible with both Windows and Linux,
greatly simplifying the scenario of using custom profiles.

> [!NOTE]
> Recent versions of Chef software are under a new license.
> Please review the [Chef InSpec downloads page](https://downloads.chef.io/inspec) for details.

## Why use InSpec with Azure Policy?

The benefit of combining your InSpec profiles with Azure Policy
is gaining the ability to automatically audit all virtual machines
across management groups (many subscriptions).
Results are available from the Guest Configuration resource provider,
which we hope to validate with Chef Automate
(community assistance would be greatly appreciated).

### Parameter support

Attribute support for Windows is currently work in progress
however it is functional for Linux using the native provider.
This means that parameters for InSpec are
actually provided at run time by the parameters
given in the ARM deployment files.

## How-To


# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
