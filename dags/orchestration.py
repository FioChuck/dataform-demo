
from airflow import models
from airflow.providers.google.cloud.hooks.dataform import DataformHook
from airflow.providers.google.cloud.operators.dataform import (
    DataformCreateCompilationResultOperator,
    DataformCreateWorkflowInvocationOperator,
)

DAG_ID = "dataform"
PROJECT_ID = "cf-data-analytics"
REPOSITORY_ID = "dataform-demo"
REGION = "us-central1"
GIT_COMMITISH = "main"


class DataformCreateWorkflowInvocationLatestOperator(DataformCreateWorkflowInvocationOperator):
    """Workflow invocation operator that dynamically resolves the latest compilation result."""

    def execute(self, context):
        if not self.workflow_invocation.get("compilation_result") and not self.workflow_invocation.get("workflow_config"):
            hook = DataformHook(
                gcp_conn_id=self.gcp_conn_id,
                impersonation_chain=self.impersonation_chain,
            )
            client = hook.get_conn()
            parent = f"projects/{self.project_id}/locations/{self.region}/repositories/{self.repository_id}"
            target_release = f"{parent}/releaseConfigs/production"

            latest_name = None
            try:
                release_config = client.get_release_config(name=target_release)
                if release_config.release_compilation_result:
                    latest_name = release_config.release_compilation_result
            except Exception as e:
                self.log.warning("Could not fetch release config %s: %s", target_release, e)

            if not latest_name:
                results = client.list_compilation_results(parent=parent)
                for r in results:
                    if getattr(r, "release_config", None) == target_release:
                        latest_name = r.name
                        break
                    if latest_name is None:
                        latest_name = r.name

            if not latest_name:
                raise ValueError(f"No compilation results found in repository {parent}")

            self.log.info("Using latest compilation result: %s", latest_name)
            self.workflow_invocation["compilation_result"] = latest_name

        return super().execute(context)


with models.DAG(
        DAG_ID,
        schedule=None,
        tags=['dataform'],
) as dag:

    # create_compilation_result = DataformCreateCompilationResultOperator(
    #     task_id="create_compilation_result",
    #     project_id=PROJECT_ID,
    #     region=REGION,
    #     repository_id=REPOSITORY_ID,
    #     compilation_result={
    #         # "git_commitish": GIT_COMMITISH,
    #         # "workspace": "projects/cf-data-analytics/locations/us-central1/repositories/dataform-demo/workspaces/cf-dev",
    #         "release_config": "projects/cf-data-analytics/locations/us-central1/repositories/dataform-demo/releaseConfigs/production"
    #     },
    # )
    create_workflow_invocation = DataformCreateWorkflowInvocationLatestOperator(
        task_id='create_workflow_invocation',
        project_id=PROJECT_ID,
        region=REGION,
        repository_id=REPOSITORY_ID,
        workflow_invocation={},
    )


# create_compilation_result >> create_workflow_invocation

if __name__ == "__main__":
    dag.cli()
    # dag.test()