#!/usr/bin/env ruby

require 'json'
require 'net/http'

# modify global variables at bottom of this file

def load_bitbucket()
  JSON.parse(IO.read('db-1.0.json'))
end

def import(bitbucket_json)
  id_map={}
  issues_count=bitbucket_json['issues'].length
  issue_id=1
  while issue_id <= issues_count
    issue=bitbucket_json['issues'].find{|h1| h1['id']==issue_id}
    gitlab_id=post_issue(issue['title'],issue['content'], issue['status'])
    id_map[issue_id]=gitlab_id
    if(['invalid', 'resolved', 'duplicate', 'wontfix', 'closed'].include? issue['status'])
      close_issue(gitlab_id)
    end
    comments=bitbucket_json['comments'].select{|h1| h1['issue']==issue_id}
    if comments.length
      comments = comments.sort_by { |k| k["id"] }
      comments.each do |comment|
        post_comment(id_map[comment['issue']],"#{comment['content']}\n\n#{comment['user']} - #{comment['created_on']}")
      end
    end
    issue_id += 1
  end
end

def gitlab_key(email,password)
  uri = URI("#{@base_url}/api/v3/session")
  res = Net::HTTP.post_form(uri, 'email' => email, 'password' => password)
  JSON.parse(res.body)['private_token']
end

def post_issue(title,description, status)
  uri = URI("#{@base_url}/api/v3/projects/#{@project}/issues")
  labels = 'bitbucket2gitlab,'+status
  res = Net::HTTP.post_form(uri, 'title' => title, 'description' => description, 'private_token' => @token, 'labels' => labels)
  created=JSON.parse(res.body)
  puts created.to_json
  created['id']
end

def post_comment(id,content)
  uri = URI("#{@base_url}/api/v3/projects/#{@project}/issues/#{id}/notes")
  res = Net::HTTP.post_form(uri, 'body' => content,'private_token' => @token)
  created=JSON.parse(res.body)
  puts created.to_json
end

def close_issue(id)

  # uri = URI("#{@base_url}/api/v3/projects/#{@project}/issues")

  request = Net::HTTP::Put.new("/api/v3/projects/#{@project}/issues/#{id}")

  request.set_form_data({'private_token' => @token,'state_event'=>'close'})
  response=@http.request(request)
  puts response.inspect
  puts response.body
end

def get_issues()
  request = Net::HTTP::Get.new("/api/v3/projects/#{@project}/issues?private_token=#{@token}")
  response=@http.request(request)
  puts response.inspect
  puts response.body
end

# gitlab host
@host="host"
@base_url="https://#{@host}/"
# add your credentials here
@token=gitlab_key('user','password')
# note the %2F to separate namespace and project
@project='inbot%2Ftest_import_issues'

# we use ssl, you should too
@http = Net::HTTP.new("#{@host}",443)
@http.use_ssl=true

# kick off the import
import(load_bitbucket())
