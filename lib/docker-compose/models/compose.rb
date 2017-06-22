require 'docker'
require_relative 'compose_port'
require_relative '../utils/compose_utils'

class Compose
  attr_reader :containers
  attr_accessor :project_name

  def initialize
    @containers = {}
    @project_name = ComposeUtils.dir_name
  end

  public

  #
  # Add a new container to compose or update existing container
  #
  def add_or_update_container(container)
    @containers[container.attributes[:label]] = container
    true
  end

  #
  # Select containers based on attributes given by "params"
  #
  def get_containers_by(params)
    @containers.values.select do |container|
      (params.to_a - container.attributes.to_a).empty?
    end
  end

  #
  # Select containers based on its given name
  # (ignore basename)
  #
  def get_containers_by_given_name(given_name)
    @containers.select { |label, container|
      container.attributes[:name].match(/#{@project_name}_#{given_name}_\d+/)
    }.values
  end

  #
  # Create link relations among containers
  #
  def link_containers
    @containers.each_value do |container|
      links = container.attributes[:links]

      next if (container.loaded_from_environment? or links.nil?)

      links.each do |service, label|
        dependency_container = @containers[service]
        container.add_dependency(dependency_container)
      end
    end
  end

  #
  # Start a container
  #
  # This method accepts an array of labels.
  # If labels is informed, only those containers with label present in array will be started.
  # Otherwise, all containers are started
  #
  def start(labels = [])
    call_container_method(:start, labels)
  end

  #
  # Stop a container
  #
  # This method accepts an array of labels.
  # If labels is informed, only those containers with label present in array will be stopped.
  # Otherwise, all containers are stopped
  #
  def stop(labels = [])
    call_container_method(:stop, labels)
  end

  #
  # Kill a container
  #
  # This method accepts an array of labels.
  # If labels is informed, only those containers with label present in array will be killed.
  # Otherwise, all containers are killed
  #
  def kill(labels  = [])
    call_container_method(:kill, labels)
  end

  #
  # Delete a container
  #
  # This method accepts an array of labels.
  # If labels is informed, only those containers with label present in array will be deleted.
  # Otherwise, all containers are deleted
  #
  def delete(labels = [])
    call_container_method(:delete, labels)
    delete_containers_entries(labels)
  end

  private

  def call_container_method(method, labels = [])
    labels = @containers.keys if labels.empty?

    containers = @containers.select { |key, value|
      labels.include?(key)
    }

    containers.values.each do |entry|
      entry.send(method)
    end

    true
  end

  def delete_containers_entries(labels = [])
    labels = @containers.keys if labels.empty?

    labels.each do |label|
      @containers.delete(label)
    end

    true
  end
end
