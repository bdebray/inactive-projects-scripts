# Identifies inactive projects 
# Barry Mullan, Rally Software (December 2014)
# Updated to pull ObjectId by Amy Meyers (March 2016)

require 'rally_api'
require 'json'
require 'csv'
require 'logger'

class RallyInactiveProjects

	def initialize configFile

		print "Reading config file #{configFile}\n"
		print "Connecting to rally\n"
		print "Running in ", Dir.pwd,"\n"

		# connect to rally.
		#Setting custom headers
		headers = RallyAPI::CustomHttpHeader.new()
		headers.name = "InactiveProjects"
		headers.vendor = "Rally"
		headers.version = "1.0"

		#or one line custom header
		headers = RallyAPI::CustomHttpHeader.new({:vendor => "Vendor", :name => "Custom Name", :version => "1.0"})

		file = File.read(configFile)
		config_hash = JSON.parse(file)

		config = {:base_url => "https://rally1.rallydev.com/slm"}
		# config[:username]   = "user.name@domain.com"
		# config[:password]   = "Password"
		config[:api_key]   = config_hash["api-key"] 
		config[:workspace] = config_hash["workspace"]
		config[:headers]    = headers #from RallyAPI::CustomHttpHeader.new()

		@rally = RallyAPI::RallyRestJson.new(config)
		@workspace 									= find_workspace(config[:workspace])
		@active_since 							= Time.parse(config_hash['active-since']).utc.iso8601
        #optional; need to check for no value
		@most_recent_creation_date	= config_hash['most_recent_creation_date'].to_s.empty? ? nil : Time.parse(config_hash['most_recent_creation_date']).utc.iso8601
		@csv_file_name 							= config_hash['csv-file-name']
		@project_name = config_hash["project"]
		@exclude_parent_projects = config_hash["exclude-parent-projects"]
		@max_artifact_count = config_hash["max-artifact-count"]

		# Logger ------------------------------------------------------------
		@logger 				          	= Logger.new('./inactive_projects.log')
		@logger.progname 						= "Inactive Projects"
		@logger.level 		        	= Logger::DEBUG # UNKNOWN | FATAL | ERROR | WARN | INFO | DEBUG

		@logger.info "Workspace:#{@workspace['Name']} active-since:#{@active_since}\n"
	end

	def close_project(project)
		begin
			@logger.info "Closing #{project.name}"

			# check if there are any open child projects
			openChildren = project['Children'].reject { |child| child['State'] == 'Closed' }
			if openChildren.length > 0 then
				@logger.info "Project has [#{openChildren.length.to_s}] open child project#{openChildren.length > 1 ? 's' : ''}. Cannot close a parent project with open child projects"
				@logger.warn "Could not close Project[#{project.name}] because it had open child projects."
			else
				fields = {}
				fields[:state] = 'Closed'
				fields[:description] = close_reason(project)

				project.update(fields)
				@logger.info("Closed Project[#{project.name}]")
			end

		rescue Exception => e
			@logger.debug "Exception Closing Project[#{project.name}]\n\tMessage:#{e.message}"
		end
	end

	# pre-pend closing reason to the description.
	def close_reason(project)
		return "Project[#{project.name}] closed on #{Time.now.utc} due to ZERO activity since #{@active_since}\n #{project.description.to_s}"
	end

	def find_workspace(name)

		query = RallyAPI::RallyQuery.new()
		query.type = "workspace"
		query.fetch = "Name,ObjectID"
		query.page_size = 200       #optional - default is 200
		# query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = true
		query.order = "Name Asc"
		query.query_string = "(Name = \"#{name}\")"

		results = @rally.find(query)

		return results.first
	end
	
	def find_project(name)

		query = RallyAPI::RallyQuery.new()
		query.type = "project"
		query.fetch = "Name,ObjectID,CreationDate"
		query.page_size = 200       #optional - default is 200
		query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = true
		query.order = "Name Asc"
		query.query_string = "(Name = \"#{name}\")"

		results = @rally.find(query)

		return results.first
	end

	def find_project(object_id, most_recent_creation_date)
		query = RallyAPI::RallyQuery.new()
		query.type = "project"
		query.fetch = "Name,Parent,State,ObjectID,Owner,TeamMembers,Children,CreationDate"
		query.page_size = 200       #optional - default is 200
		query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = false
		query.order = "Name Asc"
        
        if most_recent_creation_date.nil? and most_recent_creation_date.to_s.empty?
            query.query_string = "(ObjectID = \"#{object_id}\")"
        else
            query.query_string = "((ObjectID = \"#{object_id}\") AND (CreationDate <  \"#{most_recent_creation_date}\"))"
        end

		results = @rally.find(query)

		return results.first
	end

	def find_user(objectid)

		query = RallyAPI::RallyQuery.new()
		query.type = "user"
		query.fetch = "Name,ObjectID,UserName,EmailAddress,DisplayName"
		query.page_size = 20       #optional - default is 200
		query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = true
		query.order = "Name Asc"
		query.query_string = "(ObjectID = \"#{objectid}\")"

		results = @rally.find(query)

		return results.first
	end

	def find_projects (most_recent_creation_date)

		query = RallyAPI::RallyQuery.new()
		query.type = "project"
		query.fetch = "Name,Parent,State,ObjectID,Owner,TeamMembers,Children,CreationDate"
		query.page_size = 200       #optional - default is 200
		# query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = false
		query.order = "Name Asc"
        
        if !most_recent_creation_date.nil? and !most_recent_creation_date.to_s.empty?
            query.query_string = "(CreationDate <  \"#{most_recent_creation_date}\")"
        end
		query.workspace = @workspace

		results = @rally.find(query)
	end

	def find_project_tree (most_recent_creation_date, project_name)
		
		query = RallyAPI::RallyQuery.new()
		query.type = "project"
		query.fetch = "Name,Parent,State,ObjectID,Owner,TeamMembers,Children,CreationDate"
		query.page_size = 200       #optional - default is 200
		# query.limit = 1000          #optional - default is 99999
		query.project_scope_up = false
		query.project_scope_down = true
		query.order = "Name Asc"
        
        if most_recent_creation_date.nil? and most_recent_creation_date.to_s.empty?
            query.query_string = "(Name = \"#{project_name}\")"
        else
            query.query_string = "((CreationDate <  \"#{most_recent_creation_date}\") AND (Name = \"#{project_name}\"))"
        end
        
		query.workspace = @workspace

		results = @rally.find(query)
		
		projects = []
		results.each { |project|
			projects.push(project)
			projects.concat(find_child_projects(project, most_recent_creation_date, true))
		}

		return projects
	end

	def find_child_projects(project, most_recent_creation_date, enable_nesting)
		results = []
		if project == nil 
			return results
		elsif project['Children'] == nil 
			return results
		end

		project['Children'].each { |child_project|
			retrieved_child = find_project(child_project["ObjectID"], most_recent_creation_date)

			next if retrieved_child == nil
			
			results.push(retrieved_child)
			if enable_nesting
				results.concat(find_child_projects(retrieved_child, most_recent_creation_date, enable_nesting))
			end
		}

		return results
	end

	def find_artifacts_since (project,active_since)

		query = RallyAPI::RallyQuery.new()
		query.type = "artifact"
		query.fetch = "Name,ObjectID"
		query.page_size = 200       #optional - default is 200
		# query.limit = 1000          #optional - default is 99999
		query.project = project
		query.project_scope_up = false
		query.project_scope_down = false
		# query.order = "Name Asc"
		query.query_string = "(LastUpdateDate >= \"#{active_since}\")"
		query.workspace = @workspace

		results = @rally.find(query)
	end

	def run
		start_time = Time.now

		projects = 
			if @project_name.to_s.empty?
				print "Retrieving all projects in workspace...\n"
				@logger.info "Retrieving all projects in workspace...\n"
				find_projects(@most_recent_creation_date)
			else
				print "Retrieving project tree for #{@project_name}...\n"
				@logger.info "Retrieving project tree for #{@project_name}...\n"
				find_project_tree(@most_recent_creation_date, @project_name)
			end

		print "Found #{projects.length} projects\n"
		@logger.info "Found #{projects.length} projects\n"

		CSV.open(@csv_file_name, "wb") do |csv|
			csv << ["ObjectID","Project","Owner","EmailAddress","Parent","Artifacts Since(#{@active_since})","Project Creation Date", "Child Projects (Open)"]
			projects.each { |project| 
                
                openChildren = project['Children'].reject { |child| child['State'] == 'Closed' }
                
                # Omit projects with open child projects
                next if @exclude_parent_projects and openChildren.length > 0

				artifacts = find_artifacts_since project,@active_since

                #if set, only include those that have the specified max count (or less)
				next if !@max_artifact_count.nil? and artifacts.length > @max_artifact_count

				user = project["Owner"] ? find_user( project["Owner"].ObjectID) : nil

				userdisplay = user != nil ?  user["UserName"] : "(None)" 
				if (user != nil)
					if (user["DisplayName"] != nil)
						userdisplay = user["DisplayName"]
					else
						userdisplay = user["EmailAddress"]
					end
				else
					userdisplay = "(None)"
				end

				emaildisplay = user != nil ? user["EmailAddress"] : "(None)" 
				print "ObjectID:#{project['ObjectID']}\tProject:#{project["Name"]}\tCreated:#{project['CreationDate']}\tOwner:#{userdisplay} \tArtifacts Updated Since(#{@active_since}):\t#{artifacts.length}\n"
				@logger.info "ObjectID:#{project['ObjectID']}\tProject:#{project["Name"]}\tCreated:#{project['CreationDate']}\tOwner:#{userdisplay} \tArtifacts Updated Since(#{@active_since}):\t#{artifacts.length}\n"

				projectCreationDate = Time.parse(project["CreationDate"]).strftime("%m/%d/%Y")
				csv << [project["ObjectID"],project["Name"], userdisplay,emaildisplay, project["Parent"],artifacts.length,projectCreationDate, openChildren.length]

				##### If you wanted to automatically close projects with ZERO (0) artifacts updated since the @active_since date, UNCOMMENT the following
				# begin
				#   if artifacts.length == 0
				#     close_project(project)
				#   end
				# rescue Exception => e
				#   @logger.debug "Error closing project[#{project.name}]. Message: #{e.message}"
				# end

			}
		end
        puts "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
		@logger.info "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
	end
end

if (!ARGV[0])
	print "Usage: ruby inactive-projects.rb config_file_name.json\n"
	@logger.info "Usage: ruby inactive-projects.rb config_file_name.json\n"
else
	rtr = RallyInactiveProjects.new ARGV[0]
	rtr.run
end
