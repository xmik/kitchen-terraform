# frozen_string_literal: true

# Copyright 2016 New Context Services, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen/verifier/inspec'
require 'terraform/configurable'
require 'terraform/groups_config'

module Kitchen
  module Verifier
    # Runs tests post-converge to confirm that instances in the Terraform state
    # are in an expected state
    class Terraform < Inspec
      include ::Terraform::Configurable

      include ::Terraform::GroupsConfig

      kitchen_verifier_api_version 2

      def call(state)
        merge options: runner_options(transport, state)
        config[:groups].each { |group| group.evaluate verifier: self }
      end

      def execute
        ::Inspec::Runner.new(inspec_runner_options).tap do |inspec_runner|
          add_targets inspec_runner: inspec_runner
          verify inspec_runner: inspec_runner
        end
      end

      def merge(options:)
        inspec_runner_options.merge! options
      end

      def resolve_attributes(group:)
        group.each_attribute do |key, output_name|
          group.store_attribute key: key.to_s,
                                value: driver.output_value(name: output_name)
        end
      end

      def resolve_hostnames(group:, &block)
        driver.output_value list: true, name: group.hostnames, &block
      end

      private

      attr_accessor :inspec_runner_options

      def add_targets(inspec_runner:)
        collect_tests.each { |test| inspec_runner.add_target test }
      end

      def initialize(conf = {}, inspec_runner_options: {})
        super conf
        self.inspec_runner_options = inspec_runner_options
      end

      def verify(inspec_runner:)
        inspec_runner.run.tap do |exit_code|
          raise InstanceFailure, "Inspec Runner returns #{exit_code}" unless
            exit_code.zero?
        end
      end
    end
  end
end
