| Description 	                                                              | Command              	                               |
|-----------------------------------------------------------------------------|--------------------------------------------------------|
| Create Vagrant file in current directory (no specific image)     	      | `vagrant init`                		               |
| Create the Vagrantfile with a specific image (with "config.vm.box setting") | `vagrant init centos/7`			               |
| Create a minimal Vagrantfile (no comments or helpers)             	      | `vagrant init -m centos/7`    		               |
| Create a new Vagrantfile (overwriting the file):                            | `vagrant init -f centos/7`    		               |
| Create a Vagrantfile from the specific box URL                              | `vagrant init centos/7 [URL]` 		               |
| See all available versions of a box                               	      | `https://app.vagrantup.com/boxes/search`               |
| List all installed boxes					    	      | `vagrant box list`                                     |
| Add a box from the catalog (the latest version will be added)     	      | `vagrant box add centos/7`                             |
| Add a specific box                                                	      | `vagrant box add centos/7 --box-version 1901.01`       |
| Remove a box                                                                | `vagrant box remove centos/7`                          |
| Remove a specific version                                                   | `vagrant box remove centos/7 --box-version 1901.01`    |
| Remove all CentOS 7 boxes                                                   | `vagrant box remove centos/7 --all`                    |
| Remove all VMware CentOS 7 boxes                                            | `vagrant box remove centos/7 --provider vmware_desktop`|
| Check for a outdated box                                                    | `vagrant box outdated`                                 |
| Check all outdated boxes                                                    | `vagrant box outdated --global`                        |
| Update a box                                                                | `vagrant box update`                                   |
| Remove old versions of installed boxes                                      | `vagrant box prune`                                    |
| Create the environment 				                      | `vagrant up`                    		       | 
| Shut down a running machine                                                 | `vagrant halt`                                         | 
| Suspend a running machine					              | `vagrant suspend`		                       | 
| Resume a suspended machine					              | `vagrant resume`                                       |
| Display the status of the machine                                           | `vagrant status`                                       |
| Display the state of all active Vagrant VMs (based on the cache)            | `vagrant global-status`                                |
| Restart the machine (equivalent with halt & up)                             | `vagrant reload`                                       |
| Destroy the machine (this does not remove the box)                          | `vagrant destroy`                                      |
| Destroy the machine without confirmation                                    | `vagrant destroy -f`                                   |
| Prune invalid entries from cache				              | `vagrant global-status --prune`                        | 
| Force the provisioning					              | `vagrant provision`	                               | 
| Restart the VM and force the provision			              | `vagrant reload --provision`                           |
| List all snapshots for a VM 						      | `vagrant snapshot list`                                |
| Create a snapshot           						      | `vagrant snapshot save default <snapshot-name>`        |
| Restore a snapshot          						      | `vagrant snapshot restore <snapshot-name>`             |
| Delete a snapshot           						      | `vagrant snapshot delete <snapshot-name>`              |
| Install a plugin from a repository					      | `vagrant plugin install <plugin-name>`		       | 
| Display the full list of guest ports mapped to the host machine ports       | `vagrant port`					       |
| Update the plugins that are installed within Vagrant			      | `vagrant plugin update`                                | 
| Run ssh in debug mode							      | `vagrant ssh --debug`                                  | 
| Displays the output of the Vagrant host side SSH configuration file         | `vagrant ssh-config`                                   | 

### One liners

* Destroy all machines on VMware Fusion:

```bash
for i in `vagrant global-status | grep vmware_fusion | awk '{ print $1 }'` ; do vagrant destroy $i ; done`
```
