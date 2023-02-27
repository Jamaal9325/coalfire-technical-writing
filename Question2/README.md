Ansible Playbook: 
Windows Server Security Configuration

This playbook ensures that the required security policies are applied to a Windows Server 2019 instance, specifically the bastion1 host.

It performs the following tasks:

Ensures that "Deny access to this computer from the network" is set for Guests, Local account, and Administrators groups.
Configures Attack Surface Reduction rules for the 26190899-1602-49e8-8b27-eb1d0a1ce869 group.

Prerequisites:
Ansible 2.10 or later installed on the machine from which you'll run the playbook.
Windows Server 2019 instance with WinRM configured for Ansible.

Usage:

1.  Update the inventory.ini file to include the IP address or hostname of the bastion1 instance.
2.  Update the vars section of security-config.yml as needed.
3.  Run the playbook with the following command:
      **ansible-playbook -i inventory.ini security-config.yml**
