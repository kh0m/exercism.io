namespace :rikki do
  desc "comment on old go issues"
  task :go do
    require 'active_record'
    require 'db/connection'
    require './lib/jobs/analyze'
    require './lib/exercism'
    DB::Connection.establish

    # Select only:
    # - the most recent submission
    # - where nobody has commented
    # - that is not archived
    sql = <<-SQL
    SELECT s.key AS uuid
    FROM submissions s
    INNER JOIN user_exercises ex
    ON s.user_exercise_id=ex.id
    LEFT JOIN (
      SELECT COUNT(comments.id) AS comment_count, submissions.id
      FROM comments
      INNER JOIN submissions
      ON comments.submission_id=submissions.id
      WHERE comments.user_id<>submissions.user_id
      GROUP BY submissions.id
    ) t
    ON t.id=s.id
    WHERE s.language='go'
    AND ex.iteration_count=s.version
    AND (t.comment_count=0 OR t.id IS NULL)
    AND ex.archived='f'
    SQL

    ActiveRecord::Base.connection.execute(sql).to_a.each do |row|
      Jobs::Analyze.perform_async(row["uuid"])
    end
  end
end