#!/usr/bin/expect -f

set timeout 30
set host [lindex $argv 0]
set username [lindex $argv 1]
set passwd [lindex $argv 2]
set identity_file=/root/.ssh/id_rsa.pub

spawn ssh-copy-id -i $identity_file $username@$host
expect {
"yes/no" { send "yes\r";exp_continue }
"*assword:" { send "$passwd\r" }
}
expect eof
exit