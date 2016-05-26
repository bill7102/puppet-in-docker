require 'json'
require 'rainbow'

module Puppet # :nodoc:
  module Dockerfile # :nodoc:
    def info(message)
      puts Rainbow("==> #{message}").green
    end

    def warn(message)
      puts Rainbow("==> #{message}").yellow
    end

    def error(message)
      puts Rainbow("==> #{message}").red
    end

    def current_git_sha
      `git rev-parse HEAD`.strip
    end

    def previous_git_sha
      `git rev-parse HEAD~1`.strip
    end

    def highlight_issues(value)
      value.nil? ? Rainbow('     ').bg(:red) : value
    end

    def method_missing(method_name, *args)
      if method_name =~ /^get_(.+)_from_label$/
        get_value_from_label(*args, Regexp.last_match(1))
      elsif method_name =~ /^get_(.+)_from_dockerfile$/
        get_value_from_dockerfile(*args, Regexp.last_match(1))
      elsif method_name =~ /^get_(.+)_from_env$/
        get_value_from_env(*args, Regexp.last_match(1))
      end
    end

    def get_value_from_label(image, value)
      labels = JSON.parse(`docker inspect -f "{{json .Config.Labels }}" #{REPOSITORY}/#{image}`)
      labels["#{NAMESPACE}.#{value.tr('_', '.')}"]
    rescue
      nil
    end

    def get_value_from_dockerfile(image, value)
      text = File.read("#{image}/Dockerfile")
      text[/^#{value.upcase} (.*$)/, 1]
    end

    def get_value_from_env(image, value)
      text = File.read("#{image}/Dockerfile")
      all_labels = text[/^LABEL (.*$)/, 1]
      version = all_labels[/#{NAMESPACE}.#{value.tr('_', '.')}=([$"a-zA-Z0-9_\.]+)/, 1]
      # Versions might be ENVIRONMENT variable references
      if version.start_with?('$')
        version_reference = version
        version_reference[0] = ''
        version = text[/#{version_reference}=(["a-zA-Z0-9\.]+)/, 1]
      end
      # Environment variables might be set in the higher-level image
      if version.nil?
        base_image = get_value_from_dockerfile(image, 'from')
        base_image_without_version = base_image.split(':')[0]
        base_image_without_repo = base_image_without_version.split('/')[1]
        version = get_value_from_env(base_image_without_repo, value)
      end
      version.gsub(/\A"|"\Z/, '')
    end
  end
end
