arch-chroot /mnt /bin/bash

echo "Installing PowerCLI"
pwsh
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
install-module -name VMware.PowerCLI -force
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip `$false -Confirm:`$false -InvalidCertificateAction Ignore
exit
pwsh
install-module -name Posh-SSH
Find-Module -Name vmware* | install-module
exit