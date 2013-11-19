#
# Author:: Ezra Pagel (<ezra@cpan.org>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'
require 'netaddr'

PsOn = 'poweredOn'
PsOff = 'poweredOff'
PsSuspended = 'suspended'

PowerStates = {
    PsOn => 'powered on',
    PsOff => 'powered off',
    PsSuspended => 'suspended'
}

# Manage power state of a virtual machine
class Chef::Knife::VsphereVmState < Chef::Knife::BaseVsphereCommand

  banner "knife vsphere vm state VMNAME (options)"

  get_common_options

  option :state,
         :short => "-s STATE",
         :long => "--state STATE",
         :description => "The power state to transition the VM into; one of on|off|suspended"

  option :wait_port,
         :short => "-w PORT",
         :long => "--wait-port PORT",
         :description => "Wait for VM to be accessible on a port"

  option :shutdown,
         :short => "-g",
         :long => "--shutdown",
         :description => "Guest OS shutdown"

  def run

    $stdout.sync = true

    vmname = @name_args[0]
    if vmname.nil?
      show_usage
      ui.fatal("You must specify a virtual machine name")
      exit 1
    end

    vim = get_vim_connection

    baseFolder = find_folder(get_config(:folder));

    vm = find_in_folder(baseFolder, RbVmomi::VIM::VirtualMachine, vmname) or
        abort "VM #{vmname} not found"

    state = vm.runtime.powerState

    if config[:state].nil?
      puts "VM #{vmname} is currently " + PowerStates[vm.runtime.powerState]
    else

      case config[:state]
        when 'on'
          if state == PsOn
            puts "Virtual machine #{vmname} was already powered on"
          else
            vm.PowerOnVM_Task.wait_for_completion
            puts "Powered on virtual machine #{vmname}"
          end
        when 'off'
          if state == PsOff
            puts "Virtual machine #{vmname} was already powered off"
          else
            if get_config(:shutdown)
              vm.ShutdownGuest
              print "Waiting for virtual machine #{vmname} to shut down..."
              until vm.runtime.powerState == PsOff do
                sleep 2
                print "."
              end
              puts "done"
            else
              vm.PowerOffVM_Task.wait_for_completion
              puts "Powered off virtual machine #{vmname}"
            end
          end
        when 'suspend'
          if state == PowerStates['suspended']
            puts "Virtual machine #{vmname} was already suspended"
          else
            vm.SuspendVM_Task.wait_for_completion
            puts "Suspended virtual machine #{vmname}"
          end
        when 'reset'
          vm.ResetVM_Task.wait_for_completion
          puts "Reset virtual machine #{vmname}"
      end

      if get_config(:wait_port)
        print "Waiting for port #{get_config(:wait_port)}..."
        print "." until tcp_test_port_vm(vm, get_config(:wait_port))
        puts "done"
      end
    end
  end
end
