# Description
#   A hubot script to execute Drone CI builds
#
# Configuration:
#   HUBOT_DRONE_URL
#   HUBOT_DRONE_TOKEN
#
# Commands:
#   hubot drone project - Kicks off a drone build for the project
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Charles Butler[chuck@dasroot.net]

module.exports = (robot) ->
  robot.hear /^drone (.*)/i, (msg) ->
    project = msg.match[1]
    processBuild(msg, project)

# The current API for the self hosted DRONE implementation is a multi-step
# process.
#  - Fetch the user repository feed
#  - Locate the repository project in the repository feed
#  - Get the repository object to find the latest SHA1 of the repository
#  - POST against the repository URL to trigger a build

processBuild = (robot, project) ->
    # Validate environment settings
    if not process.env.HUBOT_DRONE_TOKEN
        msg.send "Error: No Drone token found. Please export HUBOT_DRONE_URL"
        return
    if not process.env.HUBOT_DRONE_URL
        msg.send "Error: No drone URL set. Please export HUBOT_DRONE_URL"
        return

    HUBOT_DRONE_TOKEN = process.env.HUBOT_DRONE_TOKEN
    HUBOT_DRONE_URL = process.env.HUBOT_DRONE_URL

    test_project = findRepository(robot, HUBOT_DRONE_URL, HUBOT_DRONE_TOKEN, project)

findRepository = (robot, drone_url, drone_token, project) ->
    # Pull the users repositories and find the project
    repositories = robot.http("#{drone_url}/api/user/repos?access_token=#{drone_token}").get() (err, res, body) ->
        resp = JSON.parse(body)
        for item in resp
            if item['name'] == project and item['active'] == true
                console.log("Found project: #{item['url']}")
                findSha1(robot, drone_url, drone_token, item)
                return
        robot.reply "Couldnt find a project for #{project}"


findSha1 = (robot, drone_url, drone_token, repo) ->
    # Pull the repositories and find the Sha1 sum of the commit to build
    repo_url = "#{drone_url}/api/repos/#{repo['remote']}/#{repo['owner']}/#{repo['name']}/commits?access_token=#{drone_token}"
    console.log(repo_url)
    robot.http(repo_url).get() (err, res, body) ->
        resp = JSON.parse(body)
        console.log(resp[0])
        console.log("building #{resp[0]['sha']}")
        build_url = "#{drone_url}/api/repos/#{repo['remote']}/#{repo['owner']}/#{repo['name']}/branches/#{resp[0]['branch']}/commits/#{resp[0]['sha']}?access_token=#{drone_token}"
        console.log(build_url)
        robot.http(build_url).post() (err, res, body) ->
            if err
                robot.reply "Error executing build - Check log"
            else
                robot.reply "Going HAM on #{repo['url']}:#{resp[0]['branch']} - #{resp[0]['sha']}"


