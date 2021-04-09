provider "aws" {
  region = "ca-central-1"
}

###########################################################################
#
# Create a clouldwatch dashboard
# details in the page https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/CloudWatch-Dashboard-Body-Structure.html
#
###########################################################################

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "tf-my-dashboard"

  dashboard_body = <<EOF
{
  "start": "-PT1H",
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EC2",
            "CPUUtilization",
            "InstanceId",
            "${aws_instance.web.id}"
          ],
          [
            ".",
            "NetworkIn",
            ".",
            ".",
            { "yAxis": "right" }
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ca-central-1",
        "title": "EC2 Instance CPU",
        "yAxis": {
            "right": {
                "min": 0,
                "max": 100000000
            },
            "left": {
                "min": 0,
                "max": 100
            }
         }
      }
    },
    {
      "type": "text",
      "x": 0,
      "y": 7,
      "width": 3,
      "height": 3,
      "properties": {
        "markdown": "Hello world"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/EC2",
            "CPUUtilization",
            "AutoScalingGroupName",
            "${aws_autoscaling_group.this.name}"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "ca-central-1",
        "title": "ASG instances CPU"
      }
    },
    {
      "type": "alarm",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
          "alarms": [
              "${aws_cloudwatch_metric_alarm.ma_cpu.arn}",
              "${aws_cloudwatch_metric_alarm.ma_asg.arn}",
              "${aws_cloudwatch_metric_alarm.ma_asg_decrease.arn}",
              "${aws_cloudwatch_metric_alarm.ma_exp.arn}",
              "${aws_cloudwatch_metric_alarm.ma_anomaly_detection.arn}"
          ],
          "sortBy": "stateUpdatedTimestamp",
          "title": "All EC2 CPU alarms"
        }
    }  
  ]
}
EOF
}

###########################################################################
#
# Create a clouldwatch alarm which moniters one ec2 instance
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_cpu" {

  # Metric
  namespace                 = "AWS/EC2"
  metric_name               = "CPUUtilization"
  dimensions                = {
        "InstanceId" = aws_instance.web.id
    }
  statistic                 = "Average"
  period                    = "300"
  
  # Conditions
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = "80"
  ## Additional configuration
  datapoints_to_alarm       = 2
  evaluation_periods        = 3
  treat_missing_data        = "missing"

  # Configure actions
  insufficient_data_actions = []
  ok_actions                = []
  alarm_actions     = []

  # Name and description
  alarm_name                = "tf-alarm-cpu"
  alarm_description         = "This metric monitors ec2 cpu utilization"
}

###########################################################################
#
# Create a clouldwatch simple alarm which moniters an asg
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_asg" {

  # Metric
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  statistic           = "Average"
  period              = "120"

  # Conditions
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "70"
  evaluation_periods  = "2"
  treat_missing_data        = "missing"

  # Configure actions
  alarm_actions     = [aws_autoscaling_policy.this.arn]

  # Name and description
  alarm_name          = "tf-alarm-asg-cpu"
  alarm_description = "This metric monitors cpu utilization ec2s in an asg."

}

###########################################################################
#
# Create a clouldwatch expression alarm which descreases instance number
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_asg_decrease" {

  # Metric
  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 30 AND m1 < 50, 1, 0)"
    label       = "normal cpu load "
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = "120"
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }

  # Conditions
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  evaluation_periods  = "2"
  treat_missing_data        = "missing"

  # Configure actions
  alarm_actions     = [aws_autoscaling_policy.remove_units.arn]

  # Name and description
  alarm_name          = "tf-alarm-asg-cpu-descrease"
  alarm_description = "This metric monitors cpu utilization ec2s in an asg."

}

###########################################################################
#
# Create a clouldwatch expression alarm with 2 metrics
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_exp" {
  alarm_name                = "tf-alarm-exp"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  threshold                 = "500000000"
  alarm_description         = "Bytes in total has exceeded 500m bits"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "SUM(METRICS())*8"
    label       = "incoming and outgoing bits"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "NetworkIn"
      namespace   = "AWS/EC2"
      period      = "300"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "NetworkOut"
      namespace   = "AWS/EC2"
      period      = "300"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.this.name
      }
    }
  }
}

###########################################################################
#
# Create a clouldwatch alarm using anomaly detection
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "ma_anomaly_detection" {
  alarm_name                = "tf-alarm-ad"
  comparison_operator       = "GreaterThanUpperThreshold"
  evaluation_periods        = "2"
  threshold_metric_id       = "e1" #If this is an alarm based on an anomaly detection model, make this value match the ID of the ANOMALY_DETECTION_BAND function.
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "CPUUtilization (Expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = "120"
      stat        = "Average"
      unit        = "Count"

      dimensions = {
        InstanceId = aws_instance.web.id
      }
    }
  }
}

###########################################################################
#
# Create a clouldwatch alarm monitoring Healthy Hosts on NLB using Target Group and NLB
#
###########################################################################

resource "aws_cloudwatch_metric_alarm" "nlb_healthyhosts" {
  count = var.example-nlb ? 1 : 0

  alarm_name          = "tf-alarm-nlb"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Number of healthy nodes in Target Group"
  actions_enabled     = "false"
  #alarm_actions       = [aws_sns_topic.sns.arn]
  #ok_actions          = [aws_sns_topic.sns.arn]
  dimensions = {
    TargetGroup  = aws_lb_target_group.this[0].arn_suffix
    LoadBalancer = aws_lb.this[0].arn_suffix
  }
}

###########################################################################
#
# Create a clouldwatch composite alarm
#
###########################################################################

resource "aws_cloudwatch_composite_alarm" "this" {
  alarm_description = "This is a composite alarm!"
  alarm_name        = "tf-alarm-composite"

  #alarm_actions = aws_sns_topic.example.arn
  #ok_actions    = aws_sns_topic.example.arn

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.ma_cpu.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.ma_asg.alarm_name})"


  depends_on = [aws_cloudwatch_metric_alarm.ma_cpu, aws_cloudwatch_metric_alarm.ma_asg]

}

###########################################################################
#
# Create a clouldwatch log group to store customized logs using cloudwatch agent
#
###########################################################################

resource "aws_cloudwatch_log_group" "this" {
  name = "customized-logs-ec2"

  retention_in_days = 0
  # kms_key_id =

  tags = {
    Environment = "test"
    Application = "nginx"
  }
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = "SampleLogStream1234"
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  name           = "MyAppAccessCount"
  pattern        = ""
  log_group_name = aws_cloudwatch_log_group.this.name

  metric_transformation {
    name      = "EventCount"
    namespace = "YourNamespace"
    value     = "1"
  }
}

/*
resource "aws_cloudwatch_log_subscription_filter" "this" {
  name            = "tf_lambdafunction_logfilter"
  role_arn        = aws_iam_role.iam_for_lambda.arn
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = "logtype test"
  destination_arn = aws_kinesis_stream.test_logstream.arn
  distribution    = "Random"
}
*/

###########################################################################
#
# Create a clouldwatch log query definition
#
###########################################################################

resource "aws_cloudwatch_query_definition" "this" {
  name = "custom_query"

  log_group_names = [
    "/aws/logGroup1",
    "/aws/logGroup2"
  ]

  query_string = <<EOF
fields @timestamp, @message
| sort @timestamp desc
| limit 25
EOF
}

###########################################################################
#
# ec2 instance in the default vpc
#
###########################################################################

resource "aws_instance" "web" {
  #count = 0 #if count = 0, this instance will not be created.

  #required parametres
  ami           = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  #optional parametres
  associate_public_ip_address = true
  key_name = "key-hr123000" #key paire name exists in aws.

  vpc_security_group_ids = data.aws_security_groups.default_sg.ids

  tags = {
    Name = "HelloWorld"
  }

  user_data = <<-EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo amazon-linux-extras install -y nginx1
          sudo systemctl start nginx
          curl -s http://169.254.169.254/latest/meta-data/local-hostname | sudo tee /usr/share/nginx/html/index.html
          sudo yum install httpd-tools -y
          sudo yum install amazon-cloudwatch-agent -y
EOF
  iam_instance_profile = aws_iam_instance_profile.tf_role_cloudwatch_agent.id

  lifecycle {
      ignore_changes = [
        # Ignore changes to tags, e.g. because a management agent
        # updates these based on some ruleset managed elsewhere.
        user_data,
      ]
    }
}

###########################################################################
#
# Create an autoscaling group in the default vpc
#
###########################################################################

resource "aws_launch_template" "this" {
  name_prefix   = "tf-asg-template"
  image_id      = "ami-09934b230a2c41883"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = data.aws_security_groups.default_sg.ids
  }

  key_name = "key-hr123000" #key paire name exists in aws.

  user_data = base64encode(<<-EOF
          #! /bin/sh
          sudo yum update -y
          sudo amazon-linux-extras install epel -y 
          sudo amazon-linux-extras install -y nginx1
          sudo systemctl start nginx
          curl -s http://169.254.169.254/latest/meta-data/local-hostname | sudo tee /usr/share/nginx/html/index.html
          sudo yum install httpd-tools -y
EOF
)

  tags = {
    Name = "tf-asg-template"
  }

}

resource "aws_autoscaling_group" "this" {
  desired_capacity   = 1
  max_size           = 4
  min_size           = 1
  vpc_zone_identifier = data.aws_subnet_ids.default_subnets.ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [ desired_capacity, target_group_arns]
  }
}

resource "aws_autoscaling_policy" "this" {
  name                   = "tf-asg-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  #cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_autoscaling_policy" "remove_units" {
  name                   = "tf-asg-policy-decrease"
  scaling_adjustment     = -2
  adjustment_type        = "ChangeInCapacity"
  #cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

###########################################################################
#
# Create a network loadbalancer
#
###########################################################################

resource "aws_lb" "this" {
  count = var.example-nlb ? 1 : 0

  name               = "tf-nlb-cloudwatch"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.default_subnets.ids

  enable_deletion_protection = false

  tags = {
    Environment = "test"
  }
}

resource "aws_lb_target_group" "this" {
  count = var.example-nlb ? 1 : 0

  name     = "tf-nlb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        port                = "traffic-port"
        protocol            = "TCP"
        timeout             = 10
        unhealthy_threshold = 2
    }

}

resource "aws_lb_listener" "front_end" {
  count = var.example-nlb ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }
}

resource "aws_autoscaling_attachment" "this" {
  count = var.example-nlb ? 1 : 0

  autoscaling_group_name = aws_autoscaling_group.this.id
  alb_target_group_arn   = aws_lb_target_group.this[0].arn
}

###########################################################################
#
# Create an iam role pour cloudwatch agent to write logs in log group
#
###########################################################################

resource "aws_iam_role" "tf_role_cloudwatch_agent" {
  name = "tf_role_cloudwatch_agent"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}

resource "aws_iam_role_policy_attachment" "tf_role_cloudwatch_agent" {
  role       = aws_iam_role.tf_role_cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "tf_role_cloudwatch_agent" {
  name = "tf_role_cloudwatch_agent"
  role = aws_iam_role.tf_role_cloudwatch_agent.name
}