#!/usr/bin/expect -f

set timeout 300
set ip $1
set passwd $2

spawn ssh-copy-id -i ~/.ssh/id_rsa.pub root@$ip
expect {
"yes/no" { send "yes\r";exp_continue }
"password:" { send "$passwd\r" }
}
expect eof
exit