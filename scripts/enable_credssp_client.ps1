# Enable CredSSP on client side and delegate credentials to any server (*)
Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
