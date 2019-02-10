source run.sh
tar cvf bin/master0artifacts.tar.gz -C artifacts/master .
tar cvf bin/agent0artifacts.tar.gz -C artifacts/agent .
terraform init
terraform apply