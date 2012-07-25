require 'spec_helper'

describe JenkinsPayload do
  let(:project) { FactoryGirl.create(:jenkins_project, jenkins_build_name: "ProjectMonitor") }
  let(:status_content) { JenkinsAtomExample.new(atom).read }
  let(:jenkins_payload) { JenkinsPayload.for_format(:xml).new(project) }

  subject do
    PayloadProcessor.new(project, jenkins_payload).process
    project.reload
  end

  describe "project status" do
    context "when not currently building" do
      before { jenkins_payload.status_content = status_content }

      %w(success back_to_normal stable).each do |result|
        context "when build result was #{result}" do
          let(:atom) { "#{result}.atom" }
          it { should be_green }
        end
      end

      context "when build had failed" do
        let(:atom) { "failure.atom" }
        it { should be_red }
      end
    end

    context "when building" do
      it "remains green when existing status is green" do
        content = JenkinsAtomExample.new("success.atom").read
        jenkins_payload.status_content = content
        PayloadProcessor.new(project,jenkins_payload).process
        statuses = project.statuses
        content = BuildingStatusExample.new("jenkins_projectmonitor_building.atom").read
        jenkins_payload.build_status_content = content
        PayloadProcessor.new(project,jenkins_payload).process
        project.reload.should be_green
        project.statuses.should == statuses
      end

      it "remains red when existing status is red" do
        content = JenkinsAtomExample.new("failure.atom").read
        jenkins_payload.status_content = content
        PayloadProcessor.new(project,jenkins_payload).process
        statuses = project.statuses
        content = BuildingStatusExample.new("jenkins_projectmonitor_building.atom").read
        jenkins_payload.build_status_content = content
        PayloadProcessor.new(project,jenkins_payload).process
        project.reload.should be_red
        project.statuses.should == statuses
      end
    end

  end

  describe "building status" do
    let(:build_content) { BuildingStatusExample.new(atom).read }
    before { jenkins_payload.build_status_content = build_content }

    context "when building" do
      let(:atom) { "jenkins_projectmonitor_building.atom" }
      it { should be_building }
    end

    context "when not building" do
      let(:atom) { "jenkins_projectmonitor_not_building.atom" }
      it { should_not be_building }
    end
  end

  describe "saving data" do
    let(:example) { JenkinsAtomExample.new(atom) }
    let(:status_content) { example.read }
    before { jenkins_payload.status_content = status_content }

    describe "when build was successful" do
      let(:atom) { "success.atom" }

      its(:latest_status) { should be_success }

      it "return the link to the checkin" do
        subject.latest_status.url.should == example.first_css("entry:first link").attribute('href').value
      end

      it "should return the published date of the checkin" do
        subject.latest_status.published_at.should == Time.parse(example.first_css("entry:first published").content)
      end
    end

    describe "when build failed" do
      let(:atom) { "failure.atom" }

      its(:latest_status) { should_not be_success }

      it "return the link to the checkin" do
        subject.latest_status.url.should == example.first_css("entry:first link").attribute('href').value
      end

      it "should return the published date of the checkin" do
        subject.latest_status.published_at.should == Time.parse(example.first_css("entry:first published").content)
      end
    end
  end

  describe "with invalid xml" do
    let(:status_content) { "<foo><bar>baz</bar></foo>" }

    it { should_not be_building }

    it "should not create a status" do
      expect { subject }.not_to change(ProjectStatus, :count)
    end
  end
end
