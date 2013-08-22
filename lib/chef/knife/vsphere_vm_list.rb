#
# Author:: Ezra Pagel (<ezra@cpan.org>)
# License:: Apache License, Version 2.0
#
require 'chef/knife'
require 'chef/knife/BaseVsphereCommand'
require 'terminal-table/import'

# Lists all known virtual machines in the configured datacenter
class Chef::Knife::VsphereVmList < Chef::Knife::BaseVsphereCommand

	banner "knife vsphere vm list"

	get_common_options

	option :recursive,
		:long  => "--recursive",
		:short => "-r",
		:description => "Recurse down through sub-folders"

	option :only_folders,
		:long  => "--only-folders",
		:description => "Print only sub-folders"

	def traverse_folders(folder)
		puts "#{ui.color("Folder", :cyan)}: "+(folder.path[3..-1].map{|x| x[1]}.*'/')
		print_vms_in_folder(folder) unless get_config(:only_folders)
		folders = find_all_in_folder(folder, RbVmomi::VIM::Folder)
		folders.each do |child|
			traverse_folders(child)
		end
	end

	def print_vms_in_folder(folder)
		vms = find_all_in_folder(folder, RbVmomi::VIM::VirtualMachine)
		table_out = table do | t |
			t.headings = %w{NAME IP RAM CPU DISKS NICS STATE VM_TOOLS}
			vms.each do | vm |
				t << [vm.name, vm.guest.ipAddress, vm.summary.config.memorySizeMB, vm.summary.config.numCpu, vm.summary.config.numVirtualDisks, vm.summary.config.numEthernetCards, vm.summary.runtime.powerState]
			end
		end
		puts table_out
	end

	def print_subfolders(folder)
		folders = find_all_in_folder(folder, RbVmomi::VIM::Folder)
		folders.each do |subfolder|
			puts "#{ui.color("Folder Name", :cyan)}: #{subfolder.name}"
		end
	end

	def run
		$stdout.sync = true
		vim = get_vim_connection
		baseFolder = find_folder(get_config(:folder));
		if get_config(:recursive)
			traverse_folders(baseFolder)
		else
			print_subfolders(baseFolder)
			print_vms_in_folder(baseFolder)
		end
	end
end
