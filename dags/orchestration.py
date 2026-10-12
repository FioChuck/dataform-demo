from airflow import models
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateWorkflowInvocationOperator,
)

DAG_ID = "dataform"
PROJECT_ID = "cf-data-analytics"
REPOSITORY_ID = "dataform-demo"
REGION = "us-central1"
WORKFLOW_ID = "prod-workflow-curated"

with models.DAG(
    DAG_ID,
    schedule=None,
    tags=["dataform"],
) as dag:
    curated_dag = DataformCreateWorkflowInvocationOperator(
        task_id="create_workflow_invocation1",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={
            "workflow_config": (
                f"projects/{PROJECT_ID}/locations/{REGION}/repositories/{REPOSITORY_ID}/workflowConfigs/prod-workflow-curated"
            )
        },
    )

    consumption_dag = DataformCreateWorkflowInvocationOperator(
        task_id="create_workflow_invocation2",
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={
            "workflow_config": (
                f"projects/{PROJECT_ID}/locations/{REGION}/repositories/{REPOSITORY_ID}/workflowConfigs/prod-workflow-consumption"
            )
        },
    )

    curated_dag >> consumption_dag

if __name__ == "__main__":
    dag.cli()
    # dag.test()
