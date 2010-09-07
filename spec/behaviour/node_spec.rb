$LOAD_PATH.unshift File.join(File.dirname(__FILE__))
require 'spec_helper'

describe Neo4j::Node do
  before(:all) do
    FileUtils.rm_rf Neo4j.config[:storage_path]
    FileUtils.mkdir_p(Neo4j.config[:storage_path])
  end

  after(:all) do
    Neo4j.shutdown
  end

  before(:each) do
    Neo4j::Transaction.new
  end

  after(:each) do
    Neo4j::Transaction.finish
  end

  describe "Create" do
    it "created node should exist in db after transaction finish" do
      new_node = Neo4j::Node.new
      Neo4j::Transaction.finish
      Neo4j::Node.should exist(new_node)
    end

    it "created node should exist in db before transaction finish" do
      new_node = Neo4j::Node.new
      Neo4j::Node.should exist(new_node)
      Neo4j::Transaction.finish
    end
  end

  describe "Properties" do
    it "set and get String properties with the [] operator" do
      new_node = Neo4j::Node.new
      new_node[:key] = 'myvalue'
      new_node[:key].should == 'myvalue'
    end

    it "set and get Fixnum properties with the [] operator" do
      new_node = Neo4j::Node.new
      new_node[:key] = 42
      new_node[:key].should == 42
    end


    it "set and get Float properties with the [] operator" do
      new_node = Neo4j::Node.new
      new_node[:key] = 3.1415
      new_node[:key].should == 3.1415
    end

    it "set and get Boolean properties with the [] operator" do
      new_node = Neo4j::Node.new
      new_node[:key] = true
      new_node[:key].should == true
      new_node[:key] = false
      new_node[:key].should == false
    end


    it "set and get properties with the [] operator and String key" do
      new_node = Neo4j::Node.new
      new_node["a"] = 'foo'
      new_node["a"].should == 'foo'
    end
  end


  describe "Relationships" do

    def create_nodes
      #
      #  a --friend--> b  --friend--> c
      #                |              ^
      #                |              |
      #                +--- work -----+
      #                |
      #                +--- work ---> d  --- work --> e
      a = Neo4j::Node.new
      b = Neo4j::Node.new
      c = Neo4j::Node.new
      d = Neo4j::Node.new
      e = Neo4j::Node.new
      a.outgoing(:friends) << b
      b.outgoing(:friends) << c
      b.outgoing(:work) << c
      b.outgoing(:work) << d
      d.outgoing(:work) << e
      [a,b,c,d,e]
    end


    it "#outgoing(:friends) << other_node creates an outgoing relationship of type :friends" do
      a = Neo4j::Node.new
      other_node = Neo4j::Node.new

      # when
      a.outgoing(:friends) << other_node

      # then
      a.outgoing(:friends).first.should == other_node
    end

    it "#incoming(:friends) << other_node should raise an exception" do
      a = Neo4j::Node.new
      other_node = Neo4j::Node.new

      # when
      expect { a.incoming(:friends) << other_node }.to raise_error
    end

    it "#both(:friends) << other_node should raise an exception" do
      a = Neo4j::Node.new
      other_node = Neo4j::Node.new

      # when
      expect { a.both(:friends) << other_node }.to raise_error
    end

    it "#outgoing(type) should only return outgoing nodes of the given type of depth one" do
      a,b,c,d = create_nodes
      b.outgoing(:work).should include(c,d)
      [*b.outgoing(:work)].size.should == 2
    end

    it "#outgoing(type).depth(4) should only return outgoing nodes of the given type and depth" do
      a,b,c,d,e = create_nodes
      [*b.outgoing(:work).depth(4)].size.should == 3
      b.outgoing(:work).depth(4).should include(c,d,e)
    end

    it "#incoming(type).depth(2) should only return outgoing nodes of the given type and depth" do
      a,b,c,d,e = create_nodes
      [*e.incoming(:work).depth(2)].size.should == 2
      e.incoming(:work).depth(2).should include(b,d)
    end

    it "#incoming(type) should only return incoming nodes of the given type of depth one" do
      a,b,c,d = create_nodes
      c.incoming(:work).should include(b)
      [*c.incoming(:work)].size.should == 1
    end

    it "#both(type) should return both incoming and outgoing nodes of the given type of depth one" do
      a,b,c,d = create_nodes
      b.both(:friends).should include(a,c)
      [*b.both(:friends)].size.should == 2
    end

    it "#rels should return both incoming and outgoing relationship of any type of depth one" do
      a,b,c,d,e = create_nodes
#      [a,b,c,d,e].each_with_index {|n,i| puts "#{i} : id #{n.id}"}
      [*b.rels].size.should == 4
      nodes = b.rels.collect{|r| r.end_node}
      nodes.should include(b,d)
      nodes.should_not include(a,c,e)
    end

    it "#rels(:friends) should return both incoming and outgoing relationships of given type of depth one" do
      # given
      a,b,c,d,e = create_nodes

      # when
      rels = [*b.rels(:friends)]

      # then
      rels.size.should == 2
      nodes = rels.collect{|r| r.end_node}
      nodes.should include(b,c)
      nodes.should_not include(a,d,e)
    end

    it "#rels(:friends).outgoing should return only outgoing relationships of given type of depth one" do
      # given
      a,b,c,d,e = create_nodes

      # when
      rels = [*b.rels(:friends).outgoing]

      # then
      rels.size.should == 1
      nodes = rels.collect{|r| r.end_node}
      nodes.should include(c)
      nodes.should_not include(a,b,d,e)
    end


    it "#rels(:friends).incoming should return only outgoing relationships of given type of depth one" do
      # given
      a,b,c,d,e = create_nodes

      # when
      rels = [*b.rels(:friends).incoming]

      # then
      rels.size.should == 1
      nodes = rels.collect{|r| r.start_node}
      nodes.should include(a)
      nodes.should_not include(b,c,d,e)
    end

    it "#rels(:friends,:work) should return both incoming and outgoing relationships of given types of depth one" do
      # given
      a,b,c,d,e = create_nodes

      # when
      rels = [*b.rels(:friends,:work)]

      # then
      rels.size.should == 4
      nodes = rels.collect{|r| r.end_node}
      nodes.should include(b,c,d)
      nodes.should_not include(a,e)
    end

    it "#rels(:friends,:work).outgoing/incoming should raise exception" do
      node = Neo4j::Node.new
      expect{ node.rels(:friends, :work).outgoing }.to raise_error
      expect{ node.rels(:friends, :work).incoming }.to raise_error
    end

  end

end