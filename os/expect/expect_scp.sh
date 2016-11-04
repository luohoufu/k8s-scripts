#!/usr/bin/expect -f

set timeout 30

set host [lindex $argv 0]
set username [lindex $argv 1]
set passwd [lindex $argv 2]
set src_file='/ssl/*'
set dest_file='/ssl/'

spawn scp $src_file $username@$host:$dest_file  
expect {
"yes/no" { send "yes\r";exp_continue }
"*assword:" { send "$passwd\r" }
}
expect eof
exit