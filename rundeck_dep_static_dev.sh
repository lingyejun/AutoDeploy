#! /bin/bash

## Deploy automatically'shell script
## Writen by chao03.li 2017-08-08

#-----------------------------------------------------入参赋值-------------------------------------------------------
echo hostname=$HOSTNAME

source ~/.bash_profile

jar_wrapper_ops=${1}

pom_groupid=${2}
pom_artifactid=${3}
pom_version=${4}
pom_displayname=${5}

job_name=$6
build_number=$7
build_id=$8
build_url=$9
git_url=${10}
git_branch=${11}
git_commit=${12}
artifact_url=${13}
extra_options=${14}

serviceName=${pom_groupid}-${pom_artifactid}

echo job_name=$job_name
echo build_number=$build_number
echo build_id=$build_id
echo build_url=$build_url
echo git_url=$git_url
echo git_branch=$git_branch
echo git_commit=$git_commit
echo artifact_url=$artifact_url
echo pom_displayname=$pom_displayname
echo pom_version=$pom_version
echo pom_groupid=$pom_groupid
echo pom_artifactid=$pom_artifactid
echo jar_wrapper_ops=$jar_wrapper_ops
echo extra_options=$extra_options
echo serviceName=$serviceName

DEPLOY_BASE_DIR="/root/deploy"

if [ -z $jar_wrapper_ops ]; then
  echo "jar_wrapper_ops is unset";
  exit 1
fi

if [ -z $pom_groupid ]; then
  echo "pom_groupid is unset";
  exit 1
fi

if [ -z $pom_artifactid ]; then
  echo "pom_artifactid is unset";
  exit 1
fi

# 主目录
# RDECK_BASE must be set and exist
[ -z "$DEPLOY_BASE_DIR" -o ! -d "$DEPLOY_BASE_DIR" ] && {
    echo "DEPLOY_BASE_DIR not set or does not exist" ;
    exit 1 ;
}


# 二级目录：upload和static
UPLOAD_DIR="$DEPLOY_BASE_DIR/upload"
STATIC_DIR="$DEPLOY_BASE_DIR/static"
echo DEPLOY_BASE_DIR=$DEPLOY_BASE_DIR
echo UPLOAD_DIR=$UPLOAD_DIR

#此次上传的tar.gz包的具体路径
tarFullPath=${UPLOAD_DIR}/${artifact_url}
echo tarFullPath=$tarFullPath

#baseDir/instance/serviceName的一级目录
serviceBasePath=${STATIC_DIR}/${pom_groupid}/${pom_artifactid}
echo serviceBasePath=$serviceBasePath
# 创建serviceName下的子目录
# LOGS_DIR=logs
# JAR_DIR=${serviceBasePath}/jar
# LOG_DIR=${serviceBasePath}/${LOGS_DIR}
# echo JAR_DIR=$JAR_DIR
# echo LOG_DIR=$LOG_DIR

# 所有操作都要使用到pid, lock文件
# PID_FILE=$serviceBasePath/pid
# LOK_FILE=$serviceBasePath/lock
HEAD=${serviceBasePath}/HEAD
# echo "PID_FILE: $PID_FILE"
# echo "LOK_FILE: $LOK_FILE"
echo "HEAD: $HEAD"

# 其它
RETVAL=0
DATE=`/bin/date +%Y%m%d-%H%M%S`
echo DATE=$DATE

echo_success() {
    echo "[OK]"
    return 0
}

echo_failure() {
    echo "[FAILED]"
    return 1
}

checkDirWritable() {
    echo "checkDirWritable"

    # 检查主目录是否可写
    [ -w $DEPLOY_BASE_DIR ] || {
        echo "DEPLOY_BASE_DIR dir not writable: $DEPLOY_BASE_DIR"
        return 1;
    }
    # 检查UPLOAD_DIR目录是否可写
    [ -w $UPLOAD_DIR ] || {
        echo "UPLOAD_DIR dir not writable: $UPLOAD_DIR"
        return 1;
    }
    # 检查STATIC_DIR目录是否可写
    [ -w $STATIC_DIR ] || {
        echo "STATIC_DIR dir not writable: $STATIC_DIR"
        return 1;
    }
    # 检查serviceBasePath目录是否可写
    [ -w $serviceBasePath ] || {
        echo "serviceBasePath dir not writable: $serviceBasePath"
        return 1;
    }
    # # 检查JAR_DIR目录是否可写
    # [ -w $JAR_DIR ] || {
    #     echo "JAR_DIR dir not writable: $JAR_DIR"
    #     return 1;
    # }
    # # 检查LOG_DIR目录是否可写
    # [ -w $LOG_DIR ] || {
    #     echo "LOG_DIR dir not writable: $LOG_DIR"
    #     return 1;
    # }

    return 0
}


init() {
    echo "initing $serviceName"

    # 创建文件夹
    echo "Creating dir..."
    mkdir -p $UPLOAD_DIR
    mkdir -p $serviceBasePath

    # mkdir -p $JAR_DIR
    # mkdir -p $LOG_DIR

    #检查文件夹是否创建成功
    echo "Testing dir..."
    checkDirWritable

    return $?
}

deploy() {
  echo "Deploying $serviceName"

  #检查文件夹是否创建成功
  echo "Testing dir..."
  checkDirWritable
  echo $?
  if [[ $? -ne 0 ]]; then
    echo "dir illeage"
    return 1;
  fi

  [ ! -f $tarFullPath ] && {
      echo "tarFullPath not exist: $tarFullPath" ;
      return 1;
  }

  # 移动到 serviceName 中的 www 文件夹
  dstTarFullDir=$serviceBasePath/www/${build_number}
  mkdir -p $dstTarFullDir
  echo dstTarFullDir=$dstTarFullDir

  # 解压
  tar -zxvf $tarFullPath -C $dstTarFullDir

  # 删除tar包
  rm -f $tarFullPath

  # 将软引用指向新的目录
  ll $serviceBasePath
  unlink $HEAD
  ln -s $dstTarFullDir $HEAD
  ll $serviceBasePath

  return 0;
}

case "$jar_wrapper_ops" in
    init)
  init
  RETVAL=$?
  ;;
    deploy)
  deploy
  RETVAL=$?
  ;;
    start)
	start
  RETVAL=$?
	;;
    stop)
	stop
  RETVAL=$?
	;;
    restart)
	stop
	start
  RETVAL=$?
	;;
    condrestart)
	if [ -f $LOK_FILE ]; then
	    stop
	    start
	fi
	;;
    status)
	#status $rundeckd #临时去除
  status
	RETVAL=$?
	;;
    *)
	echo $"Usage: $0 {init|deploy}"
	RETVAL=1
esac

exit $RETVAL
