class ReindexRun < ActiveRecord::Base
  def self.last_run
    order('created_at').last
  end

  def self.index_changed_model_instances
    begin
      last_run_instance = last_run
      last_run_time = (last_run_instance && last_run_instance.created_at) || 100.years.ago

      this_run = ReindexRun.create!

      entity_count = reindex_entities_updated_after(last_run_time)
      notice_count = reindex_notices_updated_after(last_run_time)

      this_run.update_attributes(
        notice_count: notice_count, entity_count: entity_count,
        updated_at: Time.now
      )
    rescue => e
      $stderr.puts "Indexing did not succeed because: #{e.inspect}"
    end
  end

  private

  def self.index_model_for(model, last_run_time)
    count = 0
    batch_size = (ENV['BATCH_SIZE'] || 100).to_i
    model.where('updated_at > ? or updated_at is null', last_run_time).
      find_in_batches(batch_size: batch_size) do |instances|
      instances.each do |instance|
        instance.tire.update_index
        count = count + 1
      end
    end
    count
  end

  def self.reindex_notices_updated_after(last_run_time)
    index_model_for(Notice, last_run_time)
  end

  def self.reindex_entities_updated_after(last_run_time)
    index_model_for(Entity, last_run_time)
  end
end
