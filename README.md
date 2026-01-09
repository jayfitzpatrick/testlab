## This is a one click install for the 4 docker based apps and all required modifications to the OS to accomodate them

## Tested against Ubuntu Server 24.04 on KVM but should work on other versions
 
 
 

### Please run the following on an Ubuntu system logged in as the user ubuntu with sudo rights 

### If your user is unable to run elevated commands without being prompted for a password run this 


```
echo "ubuntu ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ubuntu
sudo chmod 440 /etc/sudoers.d/ubuntu 
```



### To run the installation

``` 
curl https://raw.githubusercontent.com/jayfitzpatrick/testlab/refs/heads/main/deploy.sh | bash - 
```



### Please note, this shall take about 15 mins to run on a 4 core / 12GB RAM VM, and it will take some time for the newly created pods to settle