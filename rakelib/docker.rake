#
# docker docker docker
#

module DockerHelper
  IMAGE_DIR = "oci-images/nokogiri-test"
  IMAGE_NAME = "ghcr.io/sparklemotion/nokogiri-test"
  RUBIES = {
    mri: ["2.5", "2.6", "2.7", "3.0"],
    truffle: ["nightly"],
  }

  class << self
    def docker_tag_for(engine, version = nil)
      [engine, version].compact.join("-")
    end

    def docker_file_for(engine, version = nil)
      File.join(IMAGE_DIR, "#{docker_tag_for(engine, version)}.dockerfile")
    end

    def docker_image_for(engine, version = nil)
      "#{IMAGE_NAME}:#{docker_tag_for(engine, version)}"
    end

    def docker_files_each
      Dir[File.join(IMAGE_DIR, "*.erb")].each do |template_path|
        tag_or_engine = File.basename(template_path).gsub(/(.*)\.erb/, '\1').to_sym
        if RUBIES.key?(tag_or_engine)
          # engine
          RUBIES[tag_or_engine].each do |version|
            dockerfile_path = docker_file_for(tag_or_engine, version)
            yield File.read(template_path), dockerfile_path, version, docker_image_for(tag_or_engine, version)
          end
        else
          # tag
          dockerfile_path = docker_file_for(tag_or_engine)
          yield File.read(template_path), dockerfile_path, nil, docker_image_for(tag_or_engine)
        end
      end
    end

    def generate_pipeline
      filename = File.join(".github", "workflows", "generate-ci-images.yml")

      pipeline_prelude = <<~EOF
        # DO NOT EDIT
        # this file is automatically generated by the "docker:pipeline" rake task
        name: Generate CI Images
        on:
          workflow_dispatch: {}
          schedule:
            - cron: "0 5 * * 3" # At 05:00 on Wednesday # https://crontab.guru/#0_5_*_*_3
        # reference: https://github.com/marketplace/actions/build-and-push-docker-images
        jobs:
          build_images:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v2
                with:
                  submodules: true
              - uses: ruby/setup-ruby@v1
                with:
                  ruby-version: "3.0"
                  bundler-cache: true
              - uses: docker/setup-buildx-action@v1
              - uses: docker/login-action@v1
                with:
                  registry: ghcr.io
                  username: ${{github.actor}}
                  password: ${{secrets.GITHUB_TOKEN}}
      EOF

      image_template = <<EOF
      - name: %{job_name}
        uses: docker/build-push-action@v2
        with:
          context: "."
          push: true
          tags: %{image_name}
          file: %{dockerfile_path}
EOF

      puts "writing #{filename} ..."
      File.open(filename, "w") do |io|
        io.write(pipeline_prelude)

        Dir.glob(File.join(IMAGE_DIR, "*.dockerfile")).each do |dockerfile|
          image_tag = Regexp.new("(.*)\.dockerfile").match(File.basename(dockerfile))[1]
          template_params = {
            job_name: image_tag,
            image_name: "#{IMAGE_NAME}:#{image_tag}",
            dockerfile_path: dockerfile,
          }
          io.write(image_template % template_params)
        end
      end
    end

    def generate_dockerfiles
      require "erb"
      DockerHelper.docker_files_each do |template, dockerfile_path, version, _|
        puts "writing #{dockerfile_path} ..."
        File.open(dockerfile_path, "w") do |dockerfile|
          Dir.chdir(File.dirname(dockerfile_path)) do
            dockerfile.write(ERB.new(template, nil, "%-").result(binding))
          end
        end
      end
    end
  end
end

namespace "docker" do
  desc "Generate an Actions pipeline to take care of everything"
  task "pipeline" => "generate" do
    DockerHelper.generate_pipeline
  end

  desc "Generate Dockerfiles"
  task "generate" do
    DockerHelper.generate_dockerfiles
  end

  desc "Build docker images for testing"
  task "build" do
    DockerHelper.docker_files_each do |_, dockerfile_path, _, docker_image|
      sh "docker build -t #{docker_image} -f #{dockerfile_path} ."
    end
  end

  desc "Push a docker image for testing"
  task "push" do
    DockerHelper.docker_files_each do |_, _, _, docker_image|
      sh "docker push #{docker_image}"
    end
  end

  desc "Pull upstream docker images"
  task "pull" do
    DockerHelper.docker_files_each do |_, dockerfile_path, _, _|
      upstream = File.read(dockerfile_path).lines.grep(/FROM/).first.split("FROM ").last
      sh "docker pull #{upstream}"
    end
  end
end

desc "Build and push a docker image for testing"
task "docker" => ["docker:generate", "docker:pull", "docker:build", "docker:push"]
