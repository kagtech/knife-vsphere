# Author:: Ian Delahorne (<ian@delahorne.com>)
# License:: Apache License, Version 2.0

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'
require 'netaddr'

class Chef::Knife::VsphereVmExecute < Chef::Knife::BaseVsphereCommand
  banner "knife vsphere vm execute VMNAME COMMAND ARGS"

  option :exec_user,
         :long => "--exec-user USER",
         :description => "User to execute as",
         :required => true

  option :exec_passwd,
         :long => "--exec-passwd PASSWORD",
         :description => "Password for execute user",
         :required => true

  option :exec_dir,
         :long => "--exec-dir DIRECTORY",
         :description => "Working directory to execute in"

  get_common_options

  def run
    $stdout.sync = true
    vmname = @name_args[0]
    if vmname.nil?
      show_usage
      fatal_exit("You must specify a virtual machine name")
    end
    command = @name_args[1]
    if command.nil?
      show_usage
      fatal_exit("You must specify a command to execute")
    end

    args = @name_args[2]
    if args.nil?
      args = ""
    end

    vim = get_vim_connection

    dcname = get_config(:vsphere_dc)
    dc = vim.serviceInstance.find_datacenter(dcname) or abort "datacenter not found"
    folder = find_folder(get_config(:folder)) || dc.vmFolder

    vm = find_in_folder(folder, RbVmomi::VIM::VirtualMachine, vmname) or
        abort "VM #{vmname} not found"

    gom = vim.serviceContent.guestOperationsManager

    guest_auth = RbVmomi::VIM::NamePasswordAuthentication(:interactiveSession => false,
                                                          :username => config[:exec_user],
                                                          :password => config[:exec_passwd])
    prog_spec = RbVmomi::VIM::GuestProgramSpec(:programPath => command,
                                               :arguments => args,
                                               :workingDirectory => get_config(:exec_dir))

    gom.processManager.StartProgramInGuest(:vm => vm, :auth => guest_auth, :spec => prog_spec)

  end
end
