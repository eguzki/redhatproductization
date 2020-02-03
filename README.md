# redhatproductization

This project builds a *personal* RHEL productization image for Docker.
 
> make RHEL_SUB_USER=eastizle RHEL_SUB_PASSWD=\*\*\* build

> make run

# Inside of the container
> kinit eastizle

> ./clone_repos.sh eastizle

# Use this target to have your SSH key copied over to the container
> make KEY_PATH=$HOME/.ssh/gerrit KEYPUB_PATH=$HOME/.ssh/gerrit.pub add-ssh-key

