require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BraveStatementAgent do
  before(:each) do
    @valid_options = Agents::BraveStatementAgent.new.default_options
    @checker = Agents::BraveStatementAgent.new(:name => "BraveStatementAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
