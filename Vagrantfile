VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    # Which V-Box?
    config.vm.box = "bento/debian-8.7"

    # Do not check for Box updates on startup
    config.vm.box_check_update = false

    # Assign IP in private network to box
    # Access to box (e.g. in browser): http://192.168.1.14
    config.vm.network :private_network, ip: "192.168.1.14", :adapter => 2

    # Port forwarding
    # Access to box (e.g. in browser): http://127.0.0.1:18998
    config.vm.network "forwarded_port", guest: 80, host: 18988
    config.vm.network "forwarded_port", guest: 3306, host: 18989

    # Folder to sync to V-Box (using rsync)
    config.vm.synced_folder ".", "/home/vagrant/php72", disabled: false

    # Shell provisioning suffices here...
    config.vm.provision :shell, path: "provision/provisioning.sh"

    # V-Box customizing
    config.vm.provider :virtualbox do |vb|
        vb.customize [
            "modifyvm", :id,
            "--memory", "1024",
            "--natdnshostresolver1", "on",
            "--natdnsproxy1", "on"
        ]

        vb.customize [
            "setextradata", :id,
            "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"
        ]
    end

end
