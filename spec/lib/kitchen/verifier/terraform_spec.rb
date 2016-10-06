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

require 'inspec'
require 'kitchen/verifier/terraform'
require 'support/terraform/configurable_context'
require 'support/terraform/configurable_examples'
require 'support/terraform/groups_config_examples'
require 'terraform/group'

RSpec.describe Kitchen::Verifier::Terraform do
  include_context 'config'

  let :described_instance do
    described_class.new config, inspec_runner_options: inspec_runner_options
  end

  let(:inspec_runner_options) { instance_double Hash }

  before do
    allow(described_instance).to receive(:inspec_runner_options).with(no_args)
      .and_return inspec_runner_options
  end

  it_behaves_like Terraform::Configurable

  it_behaves_like Terraform::GroupsConfig

  describe '#call(state)' do
    include_context '#transport'

    let(:evaluate) { receive(:evaluate).with verifier: described_instance }

    let(:group) { instance_double Terraform::Group }

    let(:merge_options) { receive(:merge).with options: runner_options }

    let(:runner_key) { instance_double Object }

    let(:runner_options) { { runner_key => runner_value } }

    let(:runner_value) { instance_double Object }

    let(:state) { instance_double Object }

    before do
      allow(described_instance).to receive(:runner_options)
        .with(transport, state).and_return runner_options

      allow(described_instance).to merge_options

      allow(config).to receive(:[]).with(:groups).and_return [group]

      allow(group).to evaluate
    end

    after { described_instance.call state }

    describe 'setting options' do
      subject { described_instance }

      it 'uses logic of Kitchen::Verifier::Inspec' do
        is_expected.to merge_options
      end
    end

    describe 'evaluating tests' do
      subject { group }

      it('each group is evaluated') { is_expected.to evaluate }
    end
  end

  describe '#execute' do
    let :add_targets do
      receive(:add_targets).with inspec_runner: inspec_runner
    end

    let(:call_method) { described_instance.execute }

    let(:inspec_runner) { instance_double Inspec::Runner }

    let(:inspec_runner_class) { class_double(Inspec::Runner).as_stubbed_const }

    let(:verify) { receive(:verify).with inspec_runner: inspec_runner }

    before do
      allow(inspec_runner_class).to receive(:new).with(inspec_runner_options)
        .and_return inspec_runner

      allow(described_instance).to add_targets

      allow(described_instance).to verify
    end

    describe 'adding the suite profile' do
      let(:test) { instance_double Object }

      before do
        allow(described_instance).to add_targets.and_call_original

        allow(described_instance).to receive(:collect_tests).with(no_args)
          .and_return [test]
      end

      after { call_method }

      subject { inspec_runner }

      it 'adds targets to the InSpec runner' do
        is_expected.to receive(:add_target).with test
      end
    end

    describe 'verifying the result' do
      before do
        allow(described_instance).to verify.and_call_original

        allow(inspec_runner).to receive(:run).with(no_args).and_return exit_code
      end

      subject { proc { call_method } }

      context 'when the exit code is 0' do
        let(:exit_code) { 0 }

        it('does not raise an error') { is_expected.to_not raise_error }
      end

      context 'when the exit code is not 0' do
        let(:exit_code) { 1 }

        it 'raises an instance failure' do
          is_expected.to raise_error Kitchen::InstanceFailure
        end
      end
    end
  end

  describe '#merge(options:)' do
    let(:options) { instance_double Object }

    after { described_instance.merge options: options }

    subject { inspec_runner_options }

    it 'prioritizes the provided options' do
      is_expected.to receive(:merge!).with options
    end
  end

  describe '#resolve_attributes(group:)' do
    include_context '#driver'

    let(:group) { instance_double Terraform::Group }

    let(:key) { instance_double Object }

    let(:key_string) { instance_double Object }

    let(:output_name) { instance_double Object }

    let(:output_value) { instance_double Object }

    before do
      allow(group).to receive(:each_attribute).with(no_args)
        .and_yield key, output_name

      allow(key).to receive(:to_s).and_return key_string

      allow(driver).to receive(:output_value).with(name: output_name)
        .and_return output_value
    end

    after { described_instance.resolve_attributes group: group }

    subject { group }

    it 'updates each attribute with the resolved output value' do
      is_expected.to receive(:store_attribute).with key: key_string,
                                                    value: output_value
    end
  end

  describe '#resolve_hostnames(group:, &block)' do
    include_context '#driver'

    let(:group) { instance_double Terraform::Group }

    let(:hostnames) { instance_double Object }

    before do
      allow(group).to receive(:hostnames).with(no_args).and_return hostnames
    end

    after { described_instance.resolve_hostnames group: group }

    subject { driver }

    it 'yields each hostname' do
      is_expected.to receive(:output_value).with list: true, name: hostnames
    end
  end
end
