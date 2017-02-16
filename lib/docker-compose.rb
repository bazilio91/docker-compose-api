require_relative 'docker-compose/models/compose'
require_relative 'docker-compose/models/compose_container'
require_relative 'version'
require_relative 'docker_compose_config'

require 'yaml'
require 'docker'

module DockerCompose
  #
  # Get Docker client object
  #
  def self.docker_client
    Docker
  end

  #
  # Load a given docker-compose file.
  # Returns a new Compose object
  #
  def self.load(filepath, do_load_running_containers = false, project_name = nil)
    unless File.exist?(filepath)
      raise ArgumentError, 'Compose file doesn\'t exists'
    end

    # Parse the docker-compose config
    config = DockerComposeConfig.new(filepath)

    compose = Compose.new
    compose.project_name = project_name if project_name

    # Load new containers
    load_containers_from_config(config, compose)

    # Load running containers
    if do_load_running_containers
      load_running_containers(compose)
    end

    # Perform containers linkage
    compose.link_containers

    compose
  end

  def self.load_containers_from_config(config, compose)
    compose_entries = config.services

    if compose_entries
      compose_entries.each do |entry|
        compose.add_container(create_container(entry, compose))
      end
    end
  end

  def self.load_running_containers(compose)
    Docker::Container
      .all(all: true)
      .select { |c| c.info['Labels']['com.docker.compose.project'] == compose.project_name }
      .each do |container|
      compose.add_container(load_running_container(container, compose))
    end
  end

  def self.create_container(attributes, compose)
    ComposeContainer.new(
      {
        label: attributes[0],
        full_name: attributes[1]['container_name'],
        image: attributes[1]['image'],
        build: attributes[1]['build'],
        links: attributes[1]['links'],
        ports: attributes[1]['ports'],
        volumes: attributes[1]['volumes'],
        volumesFrom: attributes[1]['volumes_from'],
        command: attributes[1]['command'],
        environment: attributes[1]['environment'],
        labels: attributes[1]['labels'],
        restart: attributes[1]['restart'],
        project: compose.project_name,
        cpuShares: attributes[1]['cpu_shares'],
        cpuQuota: attributes[1]['cpu_quota'],
        memLimit: attributes[1]['mem_limit'],
        memSwapLimit: attributes[1]['memswap_limit']
      }
    )
  end

  def self.load_running_container(container, compose)
    info = container.json

    container_args = {
      label: info['Name'].split(/_/)[1] || '',
      full_name: info['Name'],
      image: info['Image'],
      build: nil,
      links: info['HostConfig']['Links'],
      ports: ComposeUtils.format_ports_from_running_container(info['NetworkSettings']['Ports']),
      volumes: info['Config']['Volumes'],
      volumesFrom: info['Config']['VolumesFrom'],
      command: info['Config']['Cmd'].is_a?(Array) ? info['Config']['Cmd'].join(' ') : nil,
      environment: info['Config']['Env'],
      labels: info['Config']['Labels'],
      project: compose.project_name,
      restart: ComposeUtils.serialize_restart_spec(info['Config']['RestartPolicy']),
      cpuShares: info['Config']['CpuShares'],
      cpuQuota: info['Config']['CpuQuota'],
      memLimit: info['Config']['MemLimit'],
      memSwapLimit: info['Config']['MemSwapLimit'],
      loaded_from_environment: true
    }

    ComposeContainer.new(container_args, container)
  end

  private_class_method :load_containers_from_config,
                       :create_container,
                       :load_running_containers,
                       :load_running_container
end
