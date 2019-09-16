RSpec.describe PumaCloudwatch::Metrics::Parser do
  subject(:parser) { described_class.new(workers: workers, data: data) }

  context "clustered" do
    let(:workers) { 2 }

    # initial data does not yet have last_status filled out
    context "last_status initially empty" do
      let(:data) {
        {"started_at"=>"2019-09-14T17:18:54Z",
         "workers"=>2,
         "phase"=>0,
         "booted_workers"=>2,
         "old_workers"=>0,
         "worker_status"=>
          [{"started_at"=>"2019-09-14T17:18:54Z",
            "pid"=>17170,
            "index"=>0,
            "phase"=>0,
            "booted"=>true,
            "last_checkin"=>"2019-09-14T17:18:54Z",
            "last_status"=>{}},
           {"started_at"=>"2019-09-14T17:18:54Z",
            "pid"=>17184,
            "index"=>1,
            "phase"=>0,
            "booted"=>true,
            "last_checkin"=>"2019-09-14T17:18:54Z",
            "last_status"=>{}}]}
      }

      it "call" do
        results = parser.call
        # puts "results:"
        # pp results
        expect(results).to be_a(Array)
      end
    end

    context "last_status filled out" do
      let(:data) {
        {"started_at"=>"2019-09-16T16:12:11Z",
           "workers"=>2,
           "phase"=>0,
           "booted_workers"=>2,
           "old_workers"=>0,
           "worker_status"=>
            [{"started_at"=>"2019-09-16T16:12:11Z",
              "pid"=>19832,
              "index"=>0,
              "phase"=>0,
              "booted"=>true,
              "last_checkin"=>"2019-09-16T16:12:41Z",
              "last_status"=>
               {"backlog"=>0, "running"=>0, "pool_capacity"=>16, "max_threads"=>16}},
             {"started_at"=>"2019-09-16T16:12:11Z",
              "pid"=>19836,
              "index"=>1,
              "phase"=>0,
              "booted"=>true,
              "last_checkin"=>"2019-09-16T16:12:41Z",
              "last_status"=>
               {"backlog"=>0,
                "running"=>0,
                "pool_capacity"=>16,
                "max_threads"=>16}}]}

      }

      it "call" do
        results = parser.call
        puts "results:"
        pp results
        expect(results).to be_a(Array)
      end
    end
  end
end