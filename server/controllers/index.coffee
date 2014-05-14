moment = require 'moment'
File = require '../models/file'
Folder = require '../models/folder'


module.exports.fetch = (req, res, next, id) ->
    File.request 'all', key: id, (err, file) ->
        if err or not file or file.length is 0
            if err
                next err
            else
                res.send error:true, msg: 'File not found', 404
        else
            req.file = file[0]
            next()

module.exports.getAttachment = (req, res, next) ->
    processAttachement req, res, next, false

# Put right headers in response, then stream file to the response.
processAttachement = (req, res, next, download) ->
    id = req.params.id
    file = req.file

    if download
        contentHeader = "attachment; filename=#{file.name}"
    else
        contentHeader = "inline"
    res.setHeader 'Content-Disposition', contentHeader

    stream = file.getBinary "file", (err, resp, body) =>
        next err if err
    stream.pipe res

getFileClass = (file) ->
    switch file.type.split('/')[0]
        when 'image' then fileClass = "image"
        when 'application' then fileClass = "document"
        when 'text' then fileClass = "document"
        when 'audio' then fileClass = "music"
        when 'video' then fileClass = "video"
        else
            fileClass = "file"
    fileClass

# Prior to file creation it ensures that all parameters are correct and that no
# file already exists with the same name. Then it builds the file document from
# given information and uploaded file metadata. Once done, it performs all
# database operation and index the file name. Finally, it tags the file if the
# parent folder is tagged.
module.exports.create = (req, res, next) ->
    if not req.body.name or req.body.name is ""
        next new Error "Invalid arguments"
        res.send 500, error: "error !"
    else

        fullPath = "#{req.body.path}/#{req.body.name}"
        File.byFullPath key: fullPath, (err, sameFiles) =>
            if sameFiles.length > 0
                res.send error:true, msg: "This file already exists", 400
            else
                file = req.files["file"]
                now = moment().toISOString()
                fileClass = getFileClass file

                # calculate metadata
                data =
                    name: req.body.name
                    path: req.body.path
                    creationDate: now
                    lastModification: now
                    mime: file.type
                    size: file.size
                    tags: []
                    class: fileClass
                    clearance: 'public'

                createFile = ->
                    File.createNewFile data, file, (err, newfile) =>
                        res.send 200, "https://joseph-silvestre38.cozycloud.cc/public/files/files/#{newfile.id}"

                # find parent folder
                Folder.byFullPath key: data.path, (err, parents) =>
                    if parents.length > 0
                        # inherit parent folder tags and update its last
                        # modification date
                        parent = parents[0]
                        data.tags = parent.tags
                        parent.lastModification = now
                        parent.save (err) ->
                            if err then next err
                            else createFile()
                    else
                        createFile()
