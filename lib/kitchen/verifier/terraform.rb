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
require 'terraform/client'
require 'terraform/configurable'
require 'terraform/group_attributes_resolver'
require 'terraform/group_hostnames_resolver'
require 'terraform/groups_config'

module Kitchen
  module Verifier
    # Runs tests post-converge to confirm that instances in the Terraform state
    # are in an expected state
    class Terraform < ::Kitchen::Verifier::Inspec
      extend ::Terraform::GroupsConfig

      include ::Terraform::Configurable

      kitchen_verifier_api_version 2

      def call(state)
        resolve_groups
        groups.each_with_each_hostname do |group|
          prepare group: group
          super
        end
      end

      private

      attr_accessor :group

      def client
        @client ||=
          ::Terraform::Client.new config: provisioner, logger: debug_logger
      end

      def groups
        config[:groups]
      end

      def prepare(group:)
        info "Verifying host '#{group[:hostname]}' of group '#{group[:name]}'"
        self.group = group
        config[:attributes] = group[:attributes]
      end

      def resolve_groups
        groups.resolve_attributes(
          resolver: ::Terraform::GroupAttributesResolver.new(client: client)
        )
        groups.resolve_hostnames(
          resolver: ::Terraform::GroupHostnamesResolver.new(client: client)
        )
      end

      def runner_options(transport, state = {})
        super.merge controls: group[:controls], host: group[:hostname],
                    port: group[:port], user: group[:username]
      end
    end
  end
end
