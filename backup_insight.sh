#!/usr/bin/env bash



usage() {
    cat - <<EOF
Backup Insight is a "wannabe simple" BASH script which give you instant insight in your IOS backups. 
EOF
}



BACKUP_PATH="$1"
ROOT=$(dirname $BASH_SOURCE)
METADIR=".backup_insight"

CATEGORIES="image movie text data archive library database index empty"


error() {
    echo "${BASH_SOURCE}:${BASH_LINENO} [ERROR]: $*" 1>&2
    exit 1
}

warning() {
    echo "${BASH_SOURCE}:${BASH_LINENO} [WARNING]: $*" 1>&2
}

get_device_name() {
    plutil -convert xml1 -o - "$1/Info.plist" | xsltproc "$ROOT/stylesheet.xsl" -
}

initialize_output_directory() {
    local device_name
    
    device_name=$( get_device_name "$1" )
    mkdir -p "$device_name"
    cd "$device_name"
    echo "Analyzing backup of \"$device_name\" from \"$1\"..."
    mkdir -p $METADIR
}

copying_backup_metadata() {
    plutil -convert xml1 -o "$METADIR/Info.plist" "$BACKUP_PATH/Info.plist"
    plutil -convert xml1 -o "$METADIR/Status.plist" "$BACKUP_PATH/Status.plist"
    plutil -convert xml1 -o "$METADIR/Manifest.plist" "$BACKUP_PATH/Manifest.plist"
    cp "$BACKUP_PATH/Manifest.mbdb" "$METADIR/"
}

scan_file_types() {
    # scan all files in the backup and determine their type with the command 'file'
    find "$BACKUP_PATH" -type f -exec file {} \; | tee $METADIR/files_and_types.log

    # extract the type label, count files by type, and sort by descending count
    sed s/.*:// $METADIR/files_and_types.log | sort | uniq -c | sort -rn | tee $METADIR/count_by_types.log
}

process_categories() {
    local category

    for category in $CATEGORIES
    do
	case $category in
	    image)
		echo "Processing images..."
		process_images
		;;
	esac
    done
}

extension_for_image() {
    local image_type
    
    image_type=$(identify -format "%m" "$1")
    case $image_type in
	JPEG)
	    echo "jpg"
	    ;;
	PNG)
	    echo "png"
	    ;;
	TIFF)
	    echo "tiff"
	    ;;
    esac
    return 1
}

basename_for_image() {
    local basename

    basename=$(identify -format "%wx%h_%[EXIF:DateTime]" "$1")
    echo $basename | tr ": " "-_"
}

declare -A PREVIOUS_IMAGE_BASENAMES # !!! not supported on BASH 3 from Mac OS X Montain Lion, will need rework !!!
process_image() {
    local extension
    local image_basename
    
    extension=$(extension_for_image "$1")
    image_basename=$(basename_for_image "$1")
    [[ -z $extension ]] && warning "Failed to guess extension for: $1"
    [[ -z $image_basename ]] && warning "Failed to provide file name for: $1"

    if [[ -n "$extension" && -n "$image_basename" ]]
    then 

	if [[ -z "${PREVIOUS_IMAGE_BASENAMES[$image_basename]}" ]]
	then
	    PREVIOUS_IMAGE_BASENAMES[$image_basename]=0
	else
	    (( ++PREVIOUS_IMAGE_BASENAMES[$image_basename] ))
	fi

	ln -v "$1" "./images/${image_basename}_${PREVIOUS_IMAGE_BASENAMES[$image_basename]}.${extension}"
	[[ $? -ne 0 ]] && warning "Failed to process: $1"
    fi
}

process_images() {
    local file

    mkdir -p "./images"

    while read file
    do
	process_image "$file"
	
	# example of specific processing for JPEG files to retrieve large photos
	# using imagemagick utilities:
	# $ grep "image" $METADIR/files_and_types.log | sed s/:.*// | while read file
	# > do
	# >     identify "$file"
	# > done | tee $METADIR/images_and_attributes.log
	#
	# $ grep -E -o "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+" $METADIR/images_and_attributes.log | sort | uniq -c | sort -rn | $METADIR/count_by_image_sizes.log
        #
	# $ grep "2592x1936" $METADIR/images_and_attributes.log | sed "s/ JPEG.*//" | while read file
	# > do
	# >     timestamp=$(identify -format "%[EXIF:DateTime]" "$file")
	# >     output_basename=$(echo $timestamp | tr ": " "-_")
	# >     cp -fv "$file" ./$output_basename.jpg
        # > done
    done < <(grep "image" $METADIR/files_and_types.log | sed s/:.*//)
}

main() {
    initialize_output_directory "$BACKUP_PATH"
    copying_backup_metadata
    scan_file_types
    process_categories
    cd ..
}

if [[ $BASH_SOURCE = $0 ]]
then
    main
fi
