# LOG TRANSFORMATION: stabilize variance and normalize highly skewed data
recency_col = "Recency"
frequency_col = "Frequency"
monetary_col = "Monetary"


# In[21]:


df[["Recency", "Frequency", "Monetary"]]


# In[22]:


# 1. Inspect the original skewness (how data is spread out in a dataset)
print("Original Skewness:")
print(df[[recency_col, frequency_col, monetary_col]].skew())


# In[29]:


# 2. Apply log1p transformation to stabilize 0 or negative boundary values
# This creates 3 new unskewed columns alongside your original dataset
import numpy as np

df["log_recency"] = np.log1p(df[recency_col])
df["log_frequency"] = np.log1p(df[frequency_col])
df["log_monetary"] = np.log1p(df[monetary_col])


# In[26]:


# 3. Handle negative values if your monetary column includes product returns
# If a customer has a net-negative monetary value, log1p will output NaN.
# Replace any resulting NaNs with 0 (or drop them if preferred):
df[["log_recency", "log_frequency", "log_monetary"]] = df[
    ["log_recency", "log_frequency", "log_monetary"]
].fillna(0)


# In[27]:


# 4. Inspect the transformation results
print("\nTransformation Complete. New Skewness Rates:")
print(df[["log_recency", "log_frequency", "log_monetary"]].skew())
print("\nData Preview:")
print(df[[recency_col, "log_recency", monetary_col, "log_monetary"]].head())


# In[11]:


# Problematic Skewed for Rates frequency_col: 1.208652


# In[30]:


import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

# Step 1: Isolate the log-transformed RFM features
features = ["log_recency", "log_frequency", "log_monetary"]
X = df[features]

# Step 2: Scale the data using StandardScaler
# This centers data around 0 with a standard deviation of 1
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Convert back to a DataFrame for tracking (Optional)
df_scaled = pd.DataFrame(X_scaled, columns=features)

# Step 3: Run K-Means loop from 1 to 10 clusters
inertia_values = []
cluster_range = range(1, 11)

for k in cluster_range:
    # random_state ensures reproducible cluster initializations
    kmeans = KMeans(n_clusters=k, init="k-means++", random_state=42)
    kmeans.fit(df_scaled)
    inertia_values.append(kmeans.inertia_)  # Inertia = sum of squared distances to closest centroid

# Step 4: Plot the Elbow Curve to determine optimal clusters
plt.figure(figsize=(8, 5))
plt.plot(cluster_range, inertia_values, marker="o", linestyle="--", color="b")
plt.title("Elbow Method for Optimal K-Means Clusters")
plt.xlabel("Number of Clusters (k)")
plt.ylabel("Inertia (Within-Cluster Sum of Squares)")
plt.xticks(cluster_range)
plt.grid(True)
plt.show()


# In[31]:


# Final Model Fitting and Label Assignment
import pandas as pd
from sklearn.cluster import KMeans

# Step 1: Set the optimal number of clusters (Adjust this number based on your elbow plot)
optimal_k = 4

# Step 2: Initialize and fit the final K-Means model
kmeans = KMeans(n_clusters=optimal_k, init="k-means++", random_state=42)

# Fit the model on the scaled data and predict the cluster assignments
# Cluster labels will be integers ranging from 0 to (k-1)
df["Cluster"] = kmeans.fit_predict(X_scaled)

# Step 3: Profile the clusters to interpret customer behavior
# We aggregate the *original* un-transformed metrics to make them readable
cluster_profile = (
    df.groupby("Cluster")[["log_recency", "log_frequency", "log_monetary"]]
    .agg(["mean", "count"])
    .reset_index()
)

print("--- Customer Cluster Assignments Completed ---")
print(f"Total customers segmented into {optimal_k} groups.\n")
print("Cluster Profiles (Averages):")
print(cluster_profile)


# In[32]:


# Calculate the Average Metrics per Cluster
# Calculate the true average RFM scores for each cluster
cluster_averages = df.groupby('Cluster')[['log_recency', 'log_frequency', 'log_monetary']].mean()

# Display total customer counts per cluster alongside the averages
cluster_counts = df.groupby('Cluster').size().to_frame('customer_count')
profile_summary = cluster_averages.merge(cluster_counts, left_index=True, right_index=True)

print("--- Inspect These Averages to Assign Names ---")
print(profile_summary)


# In[33]:


# Map to Human-Readable Retail Names
persona_map = {
    0: "At Risk / Hibernating",
    1: "Champions (VIP)",
    2: "Recent / New Customers",
    3: "Loyal Customers"
}

# Apply the names to a new column
df['Customer_Segment'] = df['Cluster'].map(persona_map)

# Final verification preview
print("\n--- Final Segment Distribution Summary ---")
print(df['Customer_Segment'].value_counts())


#                         Persona Identification Rules Cheat Sheet
# 
# Champions (VIP): Lowest average recency, highest average frequency, highest average monetary value.
# 
# Loyal Customers: Low-to-medium recency, high frequency, medium-to-high monetary value.
# 
# Recent / New: Lowest recency, lowest frequency, lowest monetary value.
# 
# At Risk / Hibernating: Highest average recency (haven't returned in a long time), low frequency, low monetary value.

# In[18]:


# build two distinct visualizations:Count Bar Chart & Grid of Box Plots
import matplotlib.pyplot as plt
import seaborn as sns

# Set a clean, professional visual style for stakeholders
sns.set_theme(style="whitegrid")
plt.rcParams.update({"font.size": 11, "axes.labelsize": 12, "axes.titlesize": 14})

# -------------------------------------------------------------
# PLOT 1: Segment Size Bar Chart
# -------------------------------------------------------------
plt.figure(figsize=(10, 5))

# Order segments by size so the chart reads cleanly from top to bottom
segment_order = df["Customer_Segment"].value_counts().index

ax = sns.countplot(
    data=df,
    y="Customer_Segment",
    order=segment_order,
    palette="Blues_r",
    hue="Customer_Segment",
    legend=False,
)

# Add exact volume text labels to the end of each bar
for p in ax.patches:
    width = p.get_width()
    ax.text(
        width + (df.shape[0] * 0.01),
        p.get_y() + p.get_height() / 2,
        f"{int(width):,}",
        va="center",
        fontweight="bold",
    )

plt.title("Customer Base Distribution by RFM Segment", pad=20, weight="bold")
plt.xlabel("Number of Customers")
plt.ylabel("Segment Name")
plt.tight_layout()
plt.show()

# -------------------------------------------------------------
# PLOT 2: Behavioral Box Plots (Recency, Frequency, Monetary)
# -------------------------------------------------------------
# We use a 1x3 grid layout to compare the 3 metrics side-by-side
fig, axes = plt.subplots(1, 3, figsize=(20, 6))
metrics = ["log_recency", "log_frequency", "log_monetary"]
titles = [
    "Recency (Days Since Last Order)",
    "Frequency (Total Order Count)",
    "Monetary Value (Total Spend $)",
]

for i, metric in enumerate(metrics):
    sns.boxplot(
        data=df,
        x="Customer_Segment",
        y=metric,
        ax=axes[i],
        order=segment_order,
        palette="Set2",
        hue="Customer_Segment",
        legend=False,
        showfliers=False,  # Hides extreme statistical outliers to keep charts clean for stakeholders
    )

    axes[i].set_title(titles[i], weight="bold", pad=15)
    axes[i].set_xlabel("")  # Remove redundant x-axis labels
    axes[i].set_ylabel("")
    axes[i].tick_params(axis="x", rotation=45)  # Rotate names to prevent overlapping

plt.suptitle(
    "Customer Behavioral Breakdown Across Segments",
    fontsize=18,
    weight="bold",
    y=1.05,
)
plt.tight_layout()
plt.show()


# In[20]:


# EXPORT or Save to a Local CSV File
# -------------------------------------------------------------
import pandas as pd
from sqlalchemy import create_engine

# Step 1: Create a clean export DataFrame containing only the core identifiers
# (Replace 'customer_id' and 'Customer_Segment' with your exact column names if different)
export_columns = ["customer_id", "Customer_Segment"]
df_export = df[export_columns].rename(
    columns={"Customer_Segment": "segment_label"}
)

# -------------------------------------------------------------
# EXPORT METHOD 1: Save to a Local CSV File
# -------------------------------------------------------------
csv_filename = "customer_rfm_segments.csv"

# index=False prevents Pandas from adding an unnamed auto-incrementing row ID column
df_export.to_csv(csv_filename, index=False)
print(f"✅ Success! Local CSV file exported as: '{csv_filename}'")


# In[21]:


# EXPORT OR Write Back into Your SQL Database
# -------------------------------------------------------------
target_table_name = "customer_segment_assignments"

# Re-use your previously initialized SQLAlchemy connection engine from your setup
# If your session closed, make sure to re-run your `engine = create_engine(...)` code block first
try:
    df_export.to_sql(
        name=target_table_name,
        con=engine,
        if_exists="replace",  # Options: 'replace' to overwrite, 'append' to add to existing rows
        index=False,  # Excludes the Pandas DataFrame row indexes
        chunksize=5000,  # Streams rows in batches to protect database memory
    )
    print(
        f"✅ Success! Database table '{target_table_name}' has been created/updated."
    )
except Exception as e:
    print(f"❌ Database export failed: {e}")


# In[ ]:




